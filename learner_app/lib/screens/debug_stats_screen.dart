import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/export_summary_service.dart';
import '../game/task_queue_service.dart';
import '../metrics/metrics_store.dart';
import '../state/database_scope.dart';
import '../sync/sync_outbox_flush_service.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

/// Dev-only diagnostics (TASKS §8.5, §15.3).
class DebugStatsScreen extends StatelessWidget {
  const DebugStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Debug panel is only available in debug builds.')),
      );
    }
    final db = DatabaseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Debug stats', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: FutureBuilder<Map<String, dynamic>>(
            future: MetricsStore.load(),
            builder: (context, snap) {
              final m = snap.data ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: const Text('Last queue fill error'),
                    subtitle: Text(
                      TaskQueueService.lastFillError ?? '—',
                      softWrap: true,
                    ),
                  ),
                  ListTile(
                    title: const Text('Metrics snapshot'),
                    subtitle: Text(
                      '$m',
                      softWrap: true,
                    ),
                  ),
                  ListTile(
                    title: const Text('Model / GGUF env'),
                    subtitle: Text(
                      'IKAMVA_USE_STUB_LLM=${Platform.environment['IKAMVA_USE_STUB_LLM'] ?? 'unset'}\n'
                      'IKAMVA_GGUF=${Platform.environment['IKAMVA_GGUF'] ?? 'unset'}',
                      softWrap: true,
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final json =
                          await ExportSummaryService(db).buildSummaryJson();
                      await Clipboard.setData(ClipboardData(text: json));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Summary JSON copied.')),
                        );
                      }
                    },
                    child: const Text('Copy export summary JSON'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final n = await SyncOutboxFlushService(db).flushPending();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Flushed $n outbox rows (if URL set).')),
                        );
                      }
                    },
                    child: const Text('Try sync outbox flush'),
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
