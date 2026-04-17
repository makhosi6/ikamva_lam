import 'package:flutter/material.dart';

import '../hints/ai_multilingual_hint.dart';

/// Tabs for model-supplied multilingual hints (design §4, TASKS §9.2).
class MultilingualHintSheet extends StatelessWidget {
  const MultilingualHintSheet({super.key, required this.hint});

  final AiMultilingualHint hint;

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'English'),
      if (hint.hintXh != null) const Tab(text: 'isiXhosa'),
      if (hint.hintZu != null) const Tab(text: 'isiZulu'),
      if (hint.hintAf != null) const Tab(text: 'Afrikaans'),
    ];
    final bodies = <Widget>[
      _HintBody(text: hint.hintEn),
      if (hint.hintXh != null) _HintBody(text: hint.hintXh!),
      if (hint.hintZu != null) _HintBody(text: hint.hintZu!),
      if (hint.hintAf != null) _HintBody(text: hint.hintAf!),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hint', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TabBar(tabs: tabs, isScrollable: true),
              SizedBox(
                height: 200,
                child: TabBarView(children: bodies),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBody extends StatelessWidget {
  const _HintBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          semanticsLabel: text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
