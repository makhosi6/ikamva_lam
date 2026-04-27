import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../llm/llm_exceptions.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../state/settings_scope.dart';
import '../version.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'xh': 'isiXhosa',
    'zu': 'isiZulu',
    'af': 'Afrikaans',
  };

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _llmBusy = false;

  Future<void> _warmLlm() async {
    setState(() => _llmBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LlmService.instance.ensureReady().timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw LlmResourceException(
              'Model preparation timed out. Plug in power, free storage, '
              'or enable Low RAM and retry.',
            ),
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('On-device runtime is ready.')),
      );
    } on LlmUnavailableException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${e.message} On mobile, try Warm up model below or cold-start '
            'the app so the home hub runs setup again. Ensure '
            '`assets/models/gemma-4-E2B-it.litertlm` is in `pubspec.yaml` and rebuild.',
          ),
        ),
      );
    } on LlmResourceException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load model: $e')),
      );
    } finally {
      if (mounted) setState(() => _llmBusy = false);
    }
  }

  Future<void> _sampleGenerate() async {
    setState(() => _llmBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _SampleLlmOutputDialog(),
      );
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _llmBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Listening & hints',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Read aloud (text-to-speech)'),
                    subtitle: const Text(
                      'Hear instructions and sentences while you read.',
                    ),
                    value: settings.ttsEnabled,
                    onChanged: settings.setTtsEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voice commands'),
                    subtitle: Text(
                      kIsWeb
                          ? 'Not supported in the browser build — use iOS, Android, or desktop.'
                          : 'Mic on the game bar: say repeat, skip, read aloud, or answer by letter (A–D).',
                    ),
                    value: settings.voiceCommandsEnabled && !kIsWeb,
                    onChanged: kIsWeb ? null : settings.setVoiceCommandsEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mixed-language answer help (AI)'),
                    subtitle: const Text(
                      'On-device normalisation for answers that mix English with other languages (spec §5.2).',
                    ),
                    value: settings.normaliseMixedLanguageAnswers,
                    onChanged: settings.setNormaliseMixedLanguageAnswers,
                  ),
                  const SizedBox(height: 16),
                  Text('Hint language', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: SettingsScreen._languages.entries
                        .map(
                          (e) => ButtonSegment<String>(
                            value: e.key,
                            label: Text(e.value),
                          ),
                        )
                        .toList(),
                    selected: {settings.hintLanguageCode},
                    onSelectionChanged: (selected) {
                      if (selected.isEmpty) return;
                      settings.setHintLanguageCode(selected.first);
                    },
                  ),
                  const Divider(height: 40),
                  Text(
                    'On-device model (Gemma)',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Low RAM profile'),
                    subtitle: const Text(
                      'Smaller context (512) and CPU backend preference for weaker devices.',
                    ),
                    value: settings.lowRamProfile,
                    onChanged: (v) async {
                      await settings.setLowRamProfile(v);
                      LlmService.instance.invalidateCachedEngine();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gemma loads only from the bundled `.litertlm` in '
                    '`pubspec.yaml` (see assets/models/OBTAINING_MODELS.txt).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _llmBusy ? null : _warmLlm,
                    child: Text(_llmBusy ? 'Working…' : 'Warm up model'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _llmBusy ? null : _sampleGenerate,
                    child: const Text('Run sample JSON prompt'),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Accessibility',
                    style: theme.textTheme.titleLarge,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    subtitle: const Text(
                      'Less animation in games (recommended on older devices).',
                    ),
                    value: settings.reduceMotion,
                    onChanged: settings.setReduceMotion,
                  ),
                  const Divider(height: 40),
                  Text(
                    'Developer',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await settings.setOnboardingComplete(false);
                      if (context.mounted) context.go('/welcome');
                    },
                    child: const Text('Show welcome screen again'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Version $kAppVersion',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Streams tokens into the dialog when [LlmService.tryOpenGenerateStream] is
/// available; otherwise falls back to one-shot [LlmService.generate].
class _SampleLlmOutputDialog extends StatefulWidget {
  const _SampleLlmOutputDialog();

  @override
  State<_SampleLlmOutputDialog> createState() => _SampleLlmOutputDialogState();
}

class _SampleLlmOutputDialogState extends State<_SampleLlmOutputDialog> {
  static const _request = LlmGenerateRequest(
    prompt: ModelBoundPrompt('{"TASK":"ping","LEVEL":"A1"}'),
  );

  String _body = '';
  String? _prettyJson;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final stream = await LlmService.instance.tryOpenGenerateStream(_request);
      final buf = StringBuffer();
      if (stream != null) {
        await for (final chunk
            in stream.timeout(const Duration(seconds: 120))) {
          buf.write(chunk);
          if (mounted) setState(() => _body = buf.toString());
        }
      } else {
        final out = await LlmService.instance
            .generate(_request)
            .timeout(const Duration(seconds: 120));
        buf.write(out.text);
        if (mounted) setState(() => _body = buf.toString());
      }
      final raw = buf.toString();
      String? pretty;
      try {
        pretty = const JsonEncoder.withIndent('  ').convert(
          jsonDecode(raw) as Object,
        );
      } on Object {
        pretty = null;
      }
      if (mounted) {
        setState(() {
          _prettyJson = pretty;
          _finished = true;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _finished = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Sample output'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: _error != null
              ? Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              : SelectableText(
                  _finished && _prettyJson != null ? _prettyJson! : _body,
                  style: theme.textTheme.bodySmall,
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _finished || _error != null ? () => Navigator.of(context).pop() : null,
          child: const Text('Close'),
        ),
      ],
    );
  }
}

