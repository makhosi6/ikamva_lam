import 'package:disk_space/disk_space.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:go_router/go_router.dart';

import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/gemma_model_config.dart';
import '../llm/llm_service.dart';
import '../llm/model_prepare_config.dart';
import '../llm/model_prepare_prefs.dart';
import '../state/settings_scope.dart';
import '../state/settings_store.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

/// First launch (and recovery): download Gemma weights (**.litertlm** or
/// mobile **`.task`**, not **`-web.task`**) over HTTPS
/// (`IKAMVA_MODEL_DOWNLOAD_URL`), verify with `getActiveModel`, then persist.
///
/// Weights are **not** bundled in the APK; the plugin keeps the install on
/// disk between sessions. If the model is missing or corrupt, this flow (or
/// [FlutterGemmaLlmEngine.ensureLoaded]) downloads again.
class ModelPrepareScreen extends StatefulWidget {
  const ModelPrepareScreen({super.key});

  @override
  State<ModelPrepareScreen> createState() => _ModelPrepareScreenState();
}

class _ModelPrepareScreenState extends State<ModelPrepareScreen> {
  _Phase _phase = _Phase.checking;
  int _progress = 0;
  String? _status;
  String? _error;
  double? _freeMb;
  int? _requiredMb;
  bool _ignoreStorageCheck = false;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Leaving screen');
    super.dispose();
  }

  Future<double?> _readFreeMb() async {
    if (kIsWeb) return null;
    try {
      return await DiskSpace.getFreeDiskSpace;
    } on Object {
      return null;
    }
  }

  int _requiredFreeMbForDownload() {
    return ModelPrepareConfig.estimatedDownloadMb +
        ModelPrepareConfig.headroomMb;
  }

  /// Opens the active model like [FlutterGemmaLlmEngine] will, then **always**
  /// closes it. Leaving a leaked [InferenceModel] handle breaks the next
  /// `getActiveModel` call and can trigger purge + full re-download.
  Future<void> _openActiveModelVerifyThenClose(SettingsStore settings) async {
    final lowRam = settings.lowRamProfile;
    Future<void> openAndClose(PreferredBackend backend) async {
      final model = await FlutterGemma.getActiveModel(
        maxTokens: lowRam ? 512 : 1024,
        preferredBackend: backend,
      );
      try {
        await model.close();
      } on Object catch (e) {
        debugPrint('ModelPrepareScreen: model.close() ignored: $e');
      }
    }

    final primary = lowRam ? PreferredBackend.cpu : PreferredBackend.gpu;
    try {
      await openAndClose(primary);
    } on Object catch (e) {
      if (primary == PreferredBackend.gpu &&
          gemmaErrorLooksLikeGpuMetalDelegateFailure(e)) {
        debugPrint('ModelPrepareScreen: GPU verify failed, trying CPU: $e');
        await openAndClose(PreferredBackend.cpu);
        return;
      }
      rethrow;
    }
  }

  Future<void> _start() async {
    if (!shouldUseFlutterGemmaEngine) {
      await ModelPreparePrefs.setPrepareDone(true);
      if (mounted) context.go('/home');
      return;
    }

    if (!mounted) return;
    final settings = SettingsScope.of(context);

    if (!ModelPrepareConfig.hasNetworkModelUrl) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error =
            'This build has no model download URL. Add to your `.env` (or '
            '`--dart-define-from-file`):\n'
            'IKAMVA_MODEL_DOWNLOAD_URL=https://…/your-model.task\n\n'
            'Optional for gated Hugging Face files:\n'
            'IKAMVA_HF_TOKEN=hf_…\n\n'
            'See assets/models/OBTAINING_MODELS.txt.';
      });
      return;
    }

    final webOnlyBlock = GemmaModelConfig.mobileModelUrlBlockedReason(
      ModelPrepareConfig.networkUrl,
    );
    if (webOnlyBlock != null) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = webOnlyBlock;
      });
      return;
    }

    if (await ModelPreparePrefs.isPrepareDone()) {
      final stillReady = await probeFlutterGemmaActiveModelReady(settings);
      if (!mounted) return;
      if (stillReady) {
        context.go('/home');
        return;
      }
      await ModelPreparePrefs.setPrepareDone(false);
      if (!mounted) return;
      LlmService.instance.invalidateCachedEngine();
    }

    if (!mounted) return;
    setState(() {
      _phase = _Phase.checking;
      _status = 'Checking storage…';
      _error = null;
      _progress = 0;
    });

    final required = _requiredFreeMbForDownload();
    final free = await _readFreeMb();

    if (mounted) {
      setState(() {
        _freeMb = free;
        _requiredMb = required;
      });
    }

    if (!_ignoreStorageCheck &&
        free != null &&
        free < required &&
        mounted) {
      setState(() {
        _phase = _Phase.lowStorage;
        _status =
            'This device reports about ${free.toStringAsFixed(0)} MB free. '
            'We recommend at least $required MB for this download.';
      });
      return;
    }

    await _runInstall(settings);
  }

  Future<void> _runInstall(SettingsStore settings) async {
    _cancelToken?.cancel('Restarting install');
    _cancelToken = CancelToken();

    if (!mounted) return;

    try {
      await _openActiveModelVerifyThenClose(settings);
      LlmService.instance.invalidateCachedEngine();
      await ModelPreparePrefs.setPrepareDone(true);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.success;
        _status = 'Model is ready.';
        _progress = 100;
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) context.go('/home');
      return;
    } on Object {
      // No usable install yet — download below.
    }

    if (!mounted) return;
    setState(() {
      _phase = _Phase.installing;
      _status = 'Downloading AI model… (one-time, kept on device)';
      _progress = 0;
      _error = null;
    });

    try {
      var builder = FlutterGemma.installModel(
        modelType: ModelPrepareConfig.modelType,
        fileType: ModelPrepareConfig.fileTypeForInstallSource(
          ModelPrepareConfig.networkUrl,
        ),
      ).fromNetwork(
        ModelPrepareConfig.networkUrl,
        token: ModelPrepareConfig.hfToken.isEmpty
            ? null
            : ModelPrepareConfig.hfToken,
      );

      builder = builder
          .withProgress((p) {
            if (mounted) setState(() => _progress = p.clamp(0, 100));
          })
          .withCancelToken(_cancelToken!);

      await builder.install();

      await _openActiveModelVerifyThenClose(settings);
      LlmService.instance.invalidateCachedEngine();
      await ModelPreparePrefs.setPrepareDone(true);

      if (!mounted) return;
      setState(() {
        _phase = _Phase.success;
        _status = 'Model is ready.';
        _progress = 100;
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) context.go('/home');
    } on Object catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) {
          setState(() {
            _phase = _Phase.error;
            _error = 'Download cancelled.';
          });
        }
        return;
      }
      if (!mounted) return;
      if (gemmaErrorLooksLikeInvalidTaskArchive(e)) {
        await purgeGemmaPluginInstallCandidates();
        await ModelPreparePrefs.setPrepareDone(false);
        LlmService.instance.invalidateCachedEngine();
      }
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = gemmaErrorLooksLikeInvalidTaskArchive(e)
            ? 'The model file could not be loaded (invalid or incomplete '
                '.task archive — LiteRT zip open failed). Stale copies were '
                'removed. Verify `IKAMVA_MODEL_DOWNLOAD_URL` and optional '
                '`IKAMVA_HF_TOKEN`, then tap Retry.\n\nTechnical: $e'
            : gemmaErrorLooksLikeGpuMetalDelegateFailure(e)
                ? 'GPU acceleration failed (common on iOS Simulator or some '
                    'devices). The download is usually fine.\n\n'
                    'Turn on Low RAM profile in Settings to prefer the CPU '
                    'backend, then return to Preparing AI, or tap Retry.\n\n'
                    'Technical: $e'
                : '$e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Preparing AI', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 56,
                  color: cs.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Getting Gemma ready',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _status ??
                      'The model is downloaded once and kept on this device.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (_freeMb != null || _requiredMb != null) ...[
                  Text(
                    _freeMb != null
                        ? 'Free space (about): ${_freeMb!.toStringAsFixed(0)} MB'
                        : 'Free space: unknown',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_requiredMb != null)
                    Text(
                      'Recommended free: at least $_requiredMb MB for this step.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (settings.lowRamProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Low RAM profile is on — we will prefer a smaller context after load.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.tertiary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                if (_phase == _Phase.installing || _phase == _Phase.success) ...[
                  LinearProgressIndicator(
                    value: (_progress.clamp(0, 100)) / 100.0,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_progress.clamp(0, 100)}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_phase == _Phase.lowStorage) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() => _ignoreStorageCheck = true);
                      _start();
                    },
                    child: const Text('Try anyway'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      context.go('/home');
                    },
                    child: const Text('Not now'),
                  ),
                ],
                if (_phase == _Phase.error && _error != null) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _ignoreStorageCheck = false;
                      });
                      _start();
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await ModelPreparePrefs.setPrepareDone(true);
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                    child: const Text('Skip for now (AI may not work)'),
                  ),
                ],
                if (_phase == _Phase.installing) ...[
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () {
                      _cancelToken?.cancel('User cancelled');
                    },
                    child: const Text('Cancel download'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Phase { checking, lowStorage, installing, success, error }
