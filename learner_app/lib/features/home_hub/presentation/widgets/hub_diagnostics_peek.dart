import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../llm/model_diagnostics.dart';

/// Scrollable tail of [ModelDiagnostics] for the loaded-hub card.
class HubDiagnosticsPeek extends StatelessWidget {
  const HubDiagnosticsPeek({
    super.key,
    required this.theme,
    required this.height,
    required this.scrollController,
  });

  final ThemeData theme;
  final double height;
  final ScrollController scrollController;

  static const int _tailMax = 48;

  static List<ModelDiagnosticEvent> _tail(List<ModelDiagnosticEvent> all) {
    if (all.length <= _tailMax) return all;
    return all.sublist(all.length - _tailMax);
  }

  static String _formatLine(ModelDiagnosticEvent e) {
    final ts = e.timestamp.toIso8601String();
    final shortTs = ts.length >= 19 ? ts.substring(11, 19) : ts;
    final extra = e.data.isEmpty ? '' : ' ${jsonEncode(e.data)}';
    return '$shortTs [${e.area}/${e.action}] ${e.message}$extra';
  }

  static Widget _diagnosticsList(
    ThemeData theme,
    List<ModelDiagnosticEvent> events,
    ScrollController controller,
    double height,
  ) {
    final tail = _tail(events);
    if (tail.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No engine events yet.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ModelDiagnosticEvent>>(
      valueListenable: ModelDiagnostics.instance.events,
      builder: (context, events, _) {
        return _diagnosticsList(theme, events, scrollController, height);
      },
    );
  }
}
