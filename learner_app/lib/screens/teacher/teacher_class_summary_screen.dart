import 'package:flutter/material.dart';

import '../../data/session_repository.dart';
import '../../db/app_database.dart';
import '../../state/database_scope.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

class TeacherClassSummaryScreen extends StatelessWidget {
  const TeacherClassSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Class summary', logoHeight: 28),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Session>>(
          future: SessionRepository(db).listRecent(limit: 30),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const Center(child: Text('No sessions yet.'));
            }
            return ConstrainedContent(
              scrollable: false,
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final s = rows[i];
                  final acc = s.accuracy == null
                      ? '—'
                      : '${((s.accuracy!) * 100).round()}%';
                  final short = s.id.length <= 8 ? s.id : '${s.id.substring(0, 8)}…';
                  return ListTile(
                    title: Text('Session $short'),
                    subtitle: Text('Tasks: ${s.tasksCompleted} · Accuracy: $acc'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
