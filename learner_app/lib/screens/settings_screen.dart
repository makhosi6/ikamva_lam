import 'dart:convert';

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
            const Duration(seconds: 45),
            onTimeout: () => throw LlmResourceException(
              'Model load timed out. Try a smaller GGUF or enable Low RAM.',
            ),
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('On-device runtime is ready.')),
      );
    } on LlmUnavailableException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${e.message} Using stub until paths are set.')),
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
      final out = await LlmService.instance
          .generate(
            const LlmGenerateRequest(
              prompt: '{"TASK":"ping","LEVEL":"A1"}',
            ),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(
        jsonDecode(out) as Object,
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sample output'),
          content: SingleChildScrollView(child: Text(pretty)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
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
              return ListView(
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voice commands'),
                    subtitle: const Text(
                      'Hands-free repeat / skip (TASKS §12.3 — planned; not wired in MVP build).',
                    ),
                    trailing: const Icon(Icons.mic_none),
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
                      'Smaller context window (512) for weaker devices — pair with a smaller GGUF (e.g. E2B).',
                    ),
                    value: settings.lowRamProfile,
                    onChanged: (v) async {
                      await settings.setLowRamProfile(v);
                      LlmService.instance.invalidateCachedEngine();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set IKAMVA_GGUF and optionally IKAMVA_LLAMA_CLI, or build '
                    'native/build/bin/llama-cli — see native/README.md.',
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
