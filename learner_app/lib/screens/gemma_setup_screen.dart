import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/gemma4_model_download_service.dart';
import '../llm/gemma4_ondevice_variant.dart';
import '../llm/llm_service.dart';
import '../llm/model_asset_manifest.dart';
import '../llm/model_prepare_config.dart';
import '../llm/model_prepare_prefs.dart';
import '../state/settings_scope.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

/// Choose **Gemma 4** E2B (bundled) or E4B (download) before the home hub warms the model.
class GemmaSetupScreen extends StatefulWidget {
  const GemmaSetupScreen({super.key});

  @override
  State<GemmaSetupScreen> createState() => _GemmaSetupScreenState();
}

class _GemmaSetupScreenState extends State<GemmaSetupScreen> {
  Gemma4OnDeviceVariant _selected = Gemma4OnDeviceVariant.e2bBundled;
  double _e4bProgress = 0;
  bool _e4bDownloading = false;
  bool _busy = false;
  String? _error;
  bool _depsReady = false;
  /// `null` until [AssetManifest] is checked for bundled E2B.
  bool? _e2bAssetListed;
  bool _e2bManifestCheckStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _selected = SettingsScope.of(context).gemma4OnDeviceVariant;
      if (_selected == Gemma4OnDeviceVariant.e4bNetwork) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkE4bExists());
      }
    }
    if (!_e2bManifestCheckStarted) {
      _e2bManifestCheckStarted = true;
      unawaited(_loadBundledE2bManifestState());
    }
  }

  Future<void> _loadBundledE2bManifestState() async {
    final ok = await modelAssetListedInBundle(
      ModelPrepareConfig.bundledModelAssetPath,
    );
    if (!mounted) return;
    setState(() {
      _e2bAssetListed = ok;
      if (!ok && _selected == Gemma4OnDeviceVariant.e2bBundled) {
        _selected = Gemma4OnDeviceVariant.e4bNetwork;
      }
    });
    if (!mounted) return;
    if (!ok) {
      unawaited(_checkE4bExists());
    }
  }

  bool get _canContinue {
    if (_busy || _e4bDownloading) return false;
    if (_selected == Gemma4OnDeviceVariant.e4bNetwork) {
      return _e4bProgress >= 100;
    }
    return _e2bAssetListed == true;
  }

  Future<void> _downloadE4b() async {
    setState(() {
      _error = null;
      _e4bDownloading = true;
      _e4bProgress = 0;
    });
    try {
      await Gemma4ModelDownloadService.downloadE4b((p) {
        if (mounted) setState(() => _e4bProgress = p);
      });
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

  Future<void> _checkE4bExists() async {
    setState(() => _busy = true);
    try {
      final ok = await Gemma4ModelDownloadService.isE4bInstalled();
      if (!mounted) return;
      setState(() {
        _e4bProgress = ok ? 100 : 0;
        _error = ok ? null : 'Model not found on device.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
        title: const IkamvaAppBarTitle(title: 'On-device Gemma 4'),
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
              // [ConstrainedContent] already scrolls; use [Column] not [ListView]
              // (nested scrollables → unbounded viewport height).
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose a Gemma 4 model',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This app only supports Gemma 4. The smaller model is included '
                    'in the app; the larger one downloads once to your device.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ModelChoiceCard(
                    title: 'Gemma 4 E2B IT (~2.4 GB)',
                    subtitle: switch (_e2bAssetListed) {
                      false =>
                        'Not bundled in this build. Add '
                            '`assets/models/gemma-4-E2B-it.litertlm` per '
                            'OBTAINING_MODELS.txt and list it in pubspec.yaml, '
                            'or use E4B below.',
                      true =>
                        'Included in the app — copies to device storage on first use.',
                      null => 'Checking whether the bundled weight file is in this build…',
                    },
                    selected: _selected == Gemma4OnDeviceVariant.e2bBundled,
                    onTap: _busy || _e2bAssetListed != true
                        ? null
                        : () => setState(() {
                              _selected = Gemma4OnDeviceVariant.e2bBundled;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 12),
                  _ModelChoiceCard(
                    title: 'Gemma 4 E4B IT (~4.3 GB)',
                    subtitle: 'Download once from Hugging Face (no account required).',
                    selected: _selected == Gemma4OnDeviceVariant.e4bNetwork,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() {
                              _selected = Gemma4OnDeviceVariant.e4bNetwork;
                              _error = null;
                            });
                            unawaited(_checkE4bExists());
                          },
                  ),
                  if (_selected == Gemma4OnDeviceVariant.e4bNetwork) ...[
                    const SizedBox(height: 16),
                    if (_e4bProgress > 0 && _e4bProgress < 100) ...[
                      LinearProgressIndicator(value: _e4bProgress / 100),
                      const SizedBox(height: 8),
                      Text(
                        '${_e4bProgress.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else if (_e4bProgress >= 100) ...[
                      Text(
                        'Download complete.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: (_busy || _e4bDownloading) ? null : _downloadE4b,
                      child: Text(_e4bDownloading ? 'Downloading…' : 'Download E4B'),
                    ),
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
                  FilledButton(
                    onPressed: _canContinue && !_busy ? _complete : null,
                    child: Text(_busy ? 'Working…' : 'Continue'),
                  ),
                  if (settings.lowRamProfile) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Low RAM profile is on — the app will prefer CPU for Gemma.',
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
