import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/settings_scope.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'xh': 'isiXhosa',
    'zu': 'isiZulu',
    'af': 'Afrikaans',
  };

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
                  const SizedBox(height: 16),
                  Text('Hint language', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: _languages.entries
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
