import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../llm/android_hf_download_setup.dart';
import '../llm/download_progress_utils.dart';
import '../debug/agent_debug_log.dart';
import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/gemma_hf_model_download_service.dart';
import '../llm/hf_install_error_format.dart';
import '../llm/huggingface_auth_token_store.dart';
import '../llm/llm_exceptions.dart';
import '../llm/llm_service.dart';
import '../llm/model_prepare_config.dart';
import '../llm/model_prepare_prefs.dart';
import '../llm/on_device_gemma_variant.dart';
import '../state/settings_scope.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

/// On-device helper: choose Gemma 3n or Gemma 4, download once, continue.
class GemmaSetupScreen extends StatefulWidget {
  const GemmaSetupScreen({super.key});

  @override
  State<GemmaSetupScreen> createState() => _GemmaSetupScreenState();
}

class _GemmaSetupScreenState extends State<GemmaSetupScreen> {
  OnDeviceGemmaVariant _selected = OnDeviceGemmaVariant.gemma3nE2b;
  final Map<OnDeviceGemmaVariant, double> _progress = {
    for (final v in OnDeviceGemmaVariant.values) v: 0,
  };
  final Map<OnDeviceGemmaVariant, bool> _downloading = {
    for (final v in OnDeviceGemmaVariant.values) v: false,
  };
  bool _busy = false;
  bool _depsReady = false;

  static const int _kMaxDownloadDiagLines = 48;
  final List<String> _downloadDiagLines = [];

  void _appendDownloadDiag(String line) {
    if (!mounted) return;
    setState(() {
      if (_downloadDiagLines.length >= _kMaxDownloadDiagLines) {
        _downloadDiagLines.removeAt(0);
      }
      _downloadDiagLines.add(line);
    });
    if (_downloading[_selected] == true) {
      _presentErrorBanner(_downloadDiagLines.join('\n'));
    }
  }

  String _formatInstallError(Object e) {
    final buf = StringBuffer(rawInstallErrorLabel(e));
    if (_downloadDiagLines.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Automatic retry / status (latest last) ---');
      for (final line in _downloadDiagLines) {
        buf.writeln(line);
      }
    }
    return buf.toString();
  }

  static const Color _kErrorBannerBackground = Color(0xFFFFEBEE);
  static const Color _kErrorBannerForeground = Color(0xFFB71C1C);

  void _presentErrorBanner(String? message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearMaterialBanners();
      if (message == null || message.isEmpty) return;
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: _kErrorBannerBackground,
          leading: const Icon(Icons.error_outline, color: _kErrorBannerForeground),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(
                message,
                style: const TextStyle(
                  color: _kErrorBannerForeground,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _selected = SettingsScope.of(context).onDeviceGemmaVariant;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkSelected());
    }
  }

  Future<String> _hfToken() async =>
      (await HuggingfaceAuthTokenStore.loadToken())?.trim() ?? '';

  static double _normalizeHfPercent(double p) => normalizeHfPercent(p);

  static const double _kInstallProgressDone = 99.5;

  bool _installLooksComplete(OnDeviceGemmaVariant v) =>
      (_progress[v] ?? 0) >= _kInstallProgressDone;

  bool get _canContinue {
    if (_busy) return false;
    if (_downloading[_selected] == true && !_installLooksComplete(_selected)) {
      return false;
    }
    return _installLooksComplete(_selected);
  }

  GemmaHfModelDownloadService _svc(OnDeviceGemmaVariant v) =>
      GemmaHfModelDownloadService.forVariant(v);

  static String _aboutDownloadSize(OnDeviceGemmaVariant variant) {
    final mb = ModelPrepareConfig.estimatedInstallMbFor(variant);
    final gb = mb / 1024;
    final s = gb >= 10 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1);
    return 'About $s GB';
  }

  String _subtitleFor(OnDeviceGemmaVariant v) {
    final size = _aboutDownloadSize(v);
    return switch (v) {
      OnDeviceGemmaVariant.gemma3nE2b =>
        '$size · Recommended. Multimodal-capable Gemma 3n; works well on mid-range phones. Needs a Hugging Face token.',
      OnDeviceGemmaVariant.gemma3nE4b =>
        '$size · Stronger Gemma 3n with vision/audio subgraphs. Needs more RAM and a Hugging Face token.',
      OnDeviceGemmaVariant.gemma4E2b =>
        '$size · Gemma 4 LiteRT prize target. Text-first; public download (no HF token). Prefer CPU / Low RAM on mid-range GPUs.',
      OnDeviceGemmaVariant.gemma4E4b =>
        '$size · Larger Gemma 4 for stronger devices. Public download (no HF token).',
    };
  }

  Future<void> _finalizeIfInstalled(OnDeviceGemmaVariant v) async {
    if (_downloading[v] != true) return;
    final ok = await _svc(v).checkModelExistence(await _hfToken());
    if (!mounted || !ok) return;
    setState(() {
      _downloading[v] = false;
      _progress[v] = 100;
    });
  }

  Future<void> _checkSelected() async {
    setState(() => _busy = true);
    try {
      final ok = await _svc(_selected).checkModelExistence(await _hfToken());
      if (!mounted) return;
      final hint = ok
          ? null
          : (onDeviceGemmaVariantNeedsAuth(_selected)
              ? 'This model isn’t on the device yet. Ensure IKAMVA_HF_TOKEN is set, then tap Download.'
              : 'This model isn’t on the device yet. Tap Download below.');
      setState(() {
        _progress[_selected] = ok ? 100 : 0;
        if (ok) _downloading[_selected] = false;
      });
      _presentErrorBanner(hint);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadSelected() async {
    await ensureAndroidModelDownloadNotificationPermission();
    final svc = _svc(_selected);
    final token = await _hfToken();
    if (svc.needsAuth && token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gemma 3n downloads need a Hugging Face token. Put IKAMVA_HF_TOKEN '
            'in the repo-root .env (or dart-define) and rebuild.',
          ),
        ),
      );
      return;
    }
    final variant = _selected;
    setState(() {
      _downloadDiagLines.clear();
      _downloading[variant] = true;
      _progress[variant] = 0;
    });
    _presentErrorBanner(null);
    try {
      await svc.downloadModel(
        token: token,
        onDiagnostic: _appendDownloadDiag,
        onProgress: (p) {
          final n = _normalizeHfPercent(p);
          if (mounted) setState(() => _progress[variant] = n);
          if (n >= _kInstallProgressDone) {
            unawaited(_finalizeIfInstalled(variant));
          }
        },
      );
      if (mounted) {
        setState(() {
          _progress[variant] = 100;
          _downloadDiagLines.clear();
        });
        _presentErrorBanner(null);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _progress[variant] = 0);
        _presentErrorBanner(_formatInstallError(e));
      }
    } finally {
      if (mounted) setState(() => _downloading[variant] = false);
    }
  }

  Future<void> _complete() async {
    agentDebugLog(
      location: 'gemma_setup_screen.dart:_complete',
      message: 'setup Continue tapped',
      hypothesisId: 'A',
      data: <String, Object?>{
        'variant': _selected.name,
        'progress': _progress[_selected],
        'downloading': _downloading[_selected],
      },
    );
    final settings = SettingsScope.of(context, listen: false);
    final previous = settings.onDeviceGemmaVariant;
    setState(() => _busy = true);
    try {
      if (previous != _selected) {
        await purgeGemmaPluginInstallCandidates();
        await ModelPreparePrefs.clearPrepareDone();
      }
      await settings.setOnDeviceGemmaVariant(_selected);
      await settings.setGemma4SetupComplete(true);
      await LlmService.instance.invalidateCachedEngine();
      if (shouldUseFlutterGemmaEngine) {
        try {
          await LlmService.instance.ensureReady();
        } on LlmUnavailableException catch (e) {
          if (!mounted) return;
          _presentErrorBanner(e.message);
          return;
        } on LlmResourceException catch (e) {
          if (!mounted) return;
          _presentErrorBanner(e.message);
          return;
        } on Object catch (e) {
          if (!mounted) return;
          _presentErrorBanner(rawInstallErrorLabel(e));
          return;
        }
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = SettingsScope.of(context);
    final selectedProgress = _progress[_selected] ?? 0;
    final selectedDownloading = _downloading[_selected] == true;
    final selectedDone = _installLooksComplete(_selected);

    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Download helper'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _busy
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).clearMaterialBanners();
                        context.pop();
                      },
              )
            : null,
      ),
      body: SafeArea(
        // ListView is the primary scroller — disable ConstrainedContent's
        // SingleChildScrollView so vertical constraints stay bounded.
        child: ConstrainedContent(
          scrollable: false,
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Text(
                    'Choose an on-device model',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hints and practice tasks run fully offline after one download. '
                    'Gemma 3n is recommended for most devices; Gemma 4 is available '
                    'for the LiteRT track. Use Wi‑Fi and keep enough free storage.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final v in OnDeviceGemmaVariant.values) ...[
                    _ModelChoiceCard(
                      title: onDeviceGemmaVariantLabel(v),
                      subtitle: _subtitleFor(v),
                      selected: _selected == v,
                      onTap: _busy
                          ? null
                          : () {
                              setState(() => _selected = v);
                              _presentErrorBanner(null);
                              unawaited(_checkSelected());
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Download (${_aboutDownloadSize(_selected)})',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stay on this screen and keep Wi‑Fi on. First download can take '
                    'several minutes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedDownloading && !selectedDone) ...[
                    if (selectedProgress > 0) ...[
                      LinearProgressIndicator(value: selectedProgress / 100),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedProgress.toStringAsFixed(0)}% · ${_aboutDownloadSize(_selected)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Starting… · ${_aboutDownloadSize(_selected)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ] else if (selectedDone && !selectedDownloading) ...[
                    Text(
                      'Download finished. You can continue.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  FilledButton.tonal(
                    onPressed: (_busy || selectedDownloading)
                        ? null
                        : _downloadSelected,
                    child: Text(
                      selectedDownloading && !selectedDone
                          ? 'Downloading…'
                          : (selectedDownloading ? 'Almost done…' : 'Download'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_canContinue && !_busy) ...[
                    Text(
                      'Download the model above, then Continue.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: (_canContinue && !_busy) ? _complete : null,
                    child: Text(
                      _busy || !_canContinue ? 'Working…' : 'Continue',
                    ),
                  ),
                  if (settings.lowRamProfile) ...[
                    const SizedBox(height: 16),
                    Text(
                      'This device uses a lighter mode to save memory.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModelChoiceCard extends StatelessWidget {
  const _ModelChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
