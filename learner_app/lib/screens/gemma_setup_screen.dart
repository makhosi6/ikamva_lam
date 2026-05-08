import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/gemma4_ondevice_variant.dart';
import '../llm/gemma_hf_model_download_service.dart';
import '../llm/huggingface_auth_token_store.dart';
import '../llm/llm_exceptions.dart';
import '../llm/llm_service.dart';
import '../llm/model_prepare_config.dart';
import '../llm/model_prepare_prefs.dart';
import '../state/settings_scope.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

/// On-device lesson helper: smaller or larger model download (Gemma 4).
class GemmaSetupScreen extends StatefulWidget {
  const GemmaSetupScreen({super.key});

  @override
  State<GemmaSetupScreen> createState() => _GemmaSetupScreenState();
}

class _GemmaSetupScreenState extends State<GemmaSetupScreen> {
  Gemma4OnDeviceVariant _selected = Gemma4OnDeviceVariant.e2bHuggingFace;
  double _e2bHfProgress = 0;
  double _e4bProgress = 0;
  bool _e2bHfDownloading = false;
  bool _e4bDownloading = false;
  bool _busy = false;
  String? _error;
  bool _depsReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _selected = SettingsScope.of(context).gemma4OnDeviceVariant;
      if (_selected == Gemma4OnDeviceVariant.e2bHuggingFace) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkE2bHf());
      } else if (_selected == Gemma4OnDeviceVariant.e4bNetwork) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkE4b());
      }
    }
  }

  Future<String> _hfToken() async =>
      (await HuggingfaceAuthTokenStore.loadToken())?.trim() ?? '';

  /// [flutter_gemma] may report **0–1** or **0–100** depending on platform/build.
  static double _normalizeHfPercent(double p) {
    if (p.isNaN || p.isInfinite) return 0;
    if (p >= 0 && p <= 1.0) return (p * 100).clamp(0, 100);
    return p.clamp(0, 100);
  }

  static const double _kInstallProgressDone = 99.5;

  bool get _e2bInstallLooksComplete => _e2bHfProgress >= _kInstallProgressDone;
  bool get _e4bInstallLooksComplete => _e4bProgress >= _kInstallProgressDone;

  bool get _needsHfProgress {
    return _selected == Gemma4OnDeviceVariant.e2bHuggingFace ||
        _selected == Gemma4OnDeviceVariant.e4bNetwork;
  }

  bool get _canContinue {
    if (_busy) return false;
    // Native install can sit at 100% progress while the Dart Future is still pending;
    // don't block Continue once progress shows the transfer is done.
    if (_e2bHfDownloading &&
        _selected == Gemma4OnDeviceVariant.e2bHuggingFace &&
        !_e2bInstallLooksComplete) {
      return false;
    }
    if (_e4bDownloading &&
        _selected == Gemma4OnDeviceVariant.e4bNetwork &&
        !_e4bInstallLooksComplete) {
      return false;
    }
    return switch (_selected) {
      Gemma4OnDeviceVariant.e2bHuggingFace => _e2bInstallLooksComplete,
      Gemma4OnDeviceVariant.e4bNetwork => _e4bInstallLooksComplete,
    };
  }

  /// When progress is complete but `downloadModel()` hasn't returned yet, verify on
  /// disk and clear the "downloading" flag so the tonal button label recovers.
  Future<void> _finalizeE2bIfInstalled() async {
    if (!_e2bHfDownloading) return;
    final svc = _e2bHfSvc;
    final token = svc.needsAuth ? await _hfToken() : '';
    final ok = await svc.checkModelExistence(token);
    if (!mounted || !ok) return;
    setState(() {
      _e2bHfDownloading = false;
      _e2bHfProgress = 100;
    });
  }

  Future<void> _finalizeE4bIfInstalled() async {
    if (!_e4bDownloading) return;
    final svc = _e4bSvc;
    final token = svc.needsAuth ? await _hfToken() : '';
    final ok = await svc.checkModelExistence(token);
    if (!mounted || !ok) return;
    setState(() {
      _e4bDownloading = false;
      _e4bProgress = 100;
    });
  }

  GemmaHfModelDownloadService get _e2bHfSvc => GemmaHfModelDownloadService.e2b();
  GemmaHfModelDownloadService get _e4bSvc => GemmaHfModelDownloadService.e4b();

  /// Human-readable download size from [ModelPrepareConfig.estimatedInstallMbFor].
  static String _aboutDownloadSize(Gemma4OnDeviceVariant variant) {
    final mb = ModelPrepareConfig.estimatedInstallMbFor(variant);
    final gb = mb / 1024;
    final s = gb >= 10 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1);
    return 'About $s GB';
  }

  Future<void> _checkE2bHf() async {
    setState(() => _busy = true);
    try {
      final svc = _e2bHfSvc;
      final token = svc.needsAuth ? await _hfToken() : '';
      final ok = await svc.checkModelExistence(token);
      if (!mounted) return;
      setState(() {
        _e2bHfProgress = ok ? 100 : 0;
        if (ok) _e2bHfDownloading = false;
        _error = ok ? null : 'This model isn’t on the device yet. Tap Download below.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkE4b() async {
    setState(() => _busy = true);
    try {
      final svc = _e4bSvc;
      final token = svc.needsAuth ? await _hfToken() : '';
      final ok = await svc.checkModelExistence(token);
      if (!mounted) return;
      setState(() {
        _e4bProgress = ok ? 100 : 0;
        if (ok) _e4bDownloading = false;
        _error = ok ? null : 'This model isn’t on the device yet. Tap Download below.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadE2bHf() async {
    final svc = _e2bHfSvc;
    final token = await _hfToken();
    if (svc.needsAuth && token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This build needs a download key from your team. Ask whoever set up '
            'the app for help.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _error = null;
      _e2bHfDownloading = true;
      _e2bHfProgress = 0;
    });
    try {
      await svc.downloadModel(
        token: token,
        onProgress: (p) {
          final n = _normalizeHfPercent(p);
          if (mounted) setState(() => _e2bHfProgress = n);
          if (n >= _kInstallProgressDone) {
            unawaited(_finalizeE2bIfInstalled());
          }
        },
      );
      if (mounted) setState(() => _e2bHfProgress = 100);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _e2bHfProgress = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _e2bHfDownloading = false);
    }
  }

  Future<void> _downloadE4b() async {
    final svc = _e4bSvc;
    final token = await _hfToken();
    if (svc.needsAuth && token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This build needs a download key from your team. Ask whoever set up '
            'the app for help.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _error = null;
      _e4bDownloading = true;
      _e4bProgress = 0;
    });
    try {
      await svc.downloadModel(
        token: token,
        onProgress: (p) {
          final n = _normalizeHfPercent(p);
          if (mounted) setState(() => _e4bProgress = n);
          if (n >= _kInstallProgressDone) {
            unawaited(_finalizeE4bIfInstalled());
          }
        },
      );
      if (mounted) setState(() => _e4bProgress = 100);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _e4bProgress = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _e4bDownloading = false);
    }
  }

  Future<void> _complete() async {
    final settings = SettingsScope.of(context, listen: false);
    final previous = settings.gemma4OnDeviceVariant;
    setState(() => _busy = true);
    try {
      if (previous != _selected) {
        await purgeGemmaPluginInstallCandidates();
        await ModelPreparePrefs.clearPrepareDone();
      }
      await settings.setGemma4OnDeviceVariant(_selected);
      await settings.setGemma4SetupComplete(true);
      LlmService.instance.invalidateCachedEngine();
      if (shouldUseFlutterGemmaEngine) {
        try {
          await LlmService.instance.ensureReady();
        } on LlmUnavailableException catch (e) {
          if (!mounted) return;
          setState(() {
            _error =
                'The lesson helper could not start. ${e.message} '
                'Try Download again, or pick the other model size.';
          });
          return;
        } on LlmResourceException catch (e) {
          if (!mounted) return;
          setState(() {
            _error = e.message;
          });
          return;
        } on Object catch (e) {
          if (!mounted) return;
          setState(() {
            _error =
                'The lesson helper could not start. Check storage and Wi‑Fi, '
                'then tap Download again. (${e.toString()})';
          });
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

    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Download helper'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _busy ? null : () => context.pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose a model size',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The helper that gives hints and feedback lives on this device. '
                    'Pick one size, download it once using Wi‑Fi, then tap Continue. '
                    'You need enough free storage for the size you pick.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModelChoiceCard(
                    title: 'Smaller model (recommended)',
                    subtitle:
                        '${_aboutDownloadSize(Gemma4OnDeviceVariant.e2bHuggingFace)} download. '
                        'Fits most phones and tablets; slightly lighter quality.',
                    selected: _selected == Gemma4OnDeviceVariant.e2bHuggingFace,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() {
                              _selected = Gemma4OnDeviceVariant.e2bHuggingFace;
                              _error = null;
                            });
                            unawaited(_checkE2bHf());
                          },
                  ),
                  const SizedBox(height: 12),
                  _ModelChoiceCard(
                    title: 'Larger model',
                    subtitle:
                        '${_aboutDownloadSize(Gemma4OnDeviceVariant.e4bNetwork)} download. '
                        'Richer answers; needs more space and a stronger device.',
                    selected: _selected == Gemma4OnDeviceVariant.e4bNetwork,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() {
                              _selected = Gemma4OnDeviceVariant.e4bNetwork;
                              _error = null;
                            });
                            unawaited(_checkE4b());
                          },
                  ),
                  if (_needsHfProgress) ...[
                    const SizedBox(height: 16),
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
                    if (_selected == Gemma4OnDeviceVariant.e2bHuggingFace) ...[
                      if (_e2bHfDownloading && !_e2bInstallLooksComplete) ...[
                        if (_e2bHfProgress > 0) ...[
                          LinearProgressIndicator(value: _e2bHfProgress / 100),
                          const SizedBox(height: 8),
                          Text(
                            '${_e2bHfProgress.toStringAsFixed(0)}% · ${_aboutDownloadSize(Gemma4OnDeviceVariant.e2bHuggingFace)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            'Starting… · ${_aboutDownloadSize(Gemma4OnDeviceVariant.e2bHuggingFace)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ] else if (_e2bInstallLooksComplete && !_e2bHfDownloading) ...[
                        Text(
                          'Download finished. You can continue.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      FilledButton.tonal(
                        onPressed: (_busy || _e2bHfDownloading)
                            ? null
                            : _downloadE2bHf,
                        child: Text(
                          _e2bHfDownloading && !_e2bInstallLooksComplete
                              ? 'Downloading…'
                              : (_e2bHfDownloading
                                    ? 'Almost done…'
                                    : 'Download'),
                        ),
                      ),
                    ],
                    if (_selected == Gemma4OnDeviceVariant.e4bNetwork) ...[
                      if (_e4bDownloading && !_e4bInstallLooksComplete) ...[
                        if (_e4bProgress > 0) ...[
                          LinearProgressIndicator(value: _e4bProgress / 100),
                          const SizedBox(height: 8),
                          Text(
                            '${_e4bProgress.toStringAsFixed(0)}% · ${_aboutDownloadSize(Gemma4OnDeviceVariant.e4bNetwork)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            'Starting… · ${_aboutDownloadSize(Gemma4OnDeviceVariant.e4bNetwork)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ] else if (_e4bInstallLooksComplete && !_e4bDownloading) ...[
                        Text(
                          'Download finished. You can continue.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      FilledButton.tonal(
                        onPressed: (_busy || _e4bDownloading) ? null : _downloadE4b,
                        child: Text(
                          _e4bDownloading && !_e4bInstallLooksComplete
                              ? 'Downloading…'
                              : (_e4bDownloading
                                    ? 'Almost done…'
                                    : 'Download'),
                        ),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
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
                    child: Text(_busy || _needsHfProgress || !_canContinue ? 'Working…' : 'Continue'),
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
