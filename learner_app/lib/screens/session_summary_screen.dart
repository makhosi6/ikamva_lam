import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/attempt_repository.dart';
import '../data/session_repository.dart';
import '../db/app_database.dart';
import '../state/database_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, this.sessionId});

  /// When null, stats are not loaded (legacy entry points).
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;

    if (sessionId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const IkamvaAppBarTitle(title: 'Session done'),
        ),
        body: SafeArea(
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 64,
                  color: ik.accentSun,
                ),
                const SizedBox(height: 16),
                Text(
                  'Great work!',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a sample quest from home to see session stats from SQLite.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const _StatRow(label: 'Accuracy', value: '—'),
                const _StatRow(label: 'Hints used', value: '—'),
                const _StatRow(label: 'Tasks completed', value: '—'),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to hub'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final db = DatabaseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Session done'),
      ),
      body: SafeArea(
        child: FutureBuilder<_SessionStats?>(
          future: _loadStats(db, sessionId!),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return Center(
                child: Text(
                  'Could not load session.',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }
            final s = snap.data!;
            return ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    size: 64,
                    color: ik.accentSun,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < s.starCount ? Icons.star : Icons.star_border,
                          color: ik.accentSun,
                          size: 32,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Great work!',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here is how this session went, straight from your local attempts.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _StatRow(
                    label: 'Rolling accuracy before session',
                    value: s.baselineAccuracyLabel,
                  ),
                  _StatRow(
                    label: 'Accuracy this session',
                    value: s.accuracyLabel,
                  ),
                  _StatRow(
                    label: 'Hints used',
                    value: s.hintsUsedLabel,
                  ),
                  _StatRow(
                    label: 'Tasks completed',
                    value: '${s.tasksCompleted}',
                  ),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to hub'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<_SessionStats?> _loadStats(
    IkamvaDatabase db,
    String id,
  ) async {
    final session = await SessionRepository(db).getById(id);
    if (session == null) return null;
    final attempts = await AttemptRepository(db).listForSession(id);
    final hintAttempts = attempts.where((a) => a.usedHint).length;
    final acc = session.accuracy;
    final accLabel = acc == null ? '—' : '${(acc * 100).round()}%';
    final hintsLabel = attempts.isEmpty
        ? '—'
        : '$hintAttempts / ${attempts.length}';
    final base = session.baselineAccuracy;
    final baselineLabel =
        base == null ? '—' : '${(base * 100).round()}%';
    final stars = acc == null ? 0 : (acc * 5).round().clamp(0, 5);
    return _SessionStats(
      tasksCompleted: session.tasksCompleted,
      baselineAccuracyLabel: baselineLabel,
      accuracyLabel: accLabel,
      hintsUsedLabel: hintsLabel,
      starCount: stars,
    );
  }
}

class _SessionStats {
  _SessionStats({
    required this.tasksCompleted,
    required this.baselineAccuracyLabel,
    required this.accuracyLabel,
    required this.hintsUsedLabel,
    required this.starCount,
  });

  final int tasksCompleted;
  final String baselineAccuracyLabel;
  final String accuracyLabel;
  final String hintsUsedLabel;
  final int starCount;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
