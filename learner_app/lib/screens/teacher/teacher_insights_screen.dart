import 'package:flutter/material.dart';

import '../../data/insight_card_repository.dart';
import '../../db/app_database.dart';
import '../../db/seed.dart';
import '../../state/database_scope.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

class TeacherInsightsScreen extends StatelessWidget {
  const TeacherInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Insights', logoHeight: 28),
      ),
      body: SafeArea(
        child: FutureBuilder<List<InsightCard>>(
          future: InsightCardRepository(db).listForLearner(kSeedLearnerId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snap.data!;
            if (cards.isEmpty) {
              return const Center(
                child: Text('No insight cards yet. Finish a session with weak skills.'),
              );
            }
            return ConstrainedContent(
              child: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, i) {
                  final c = cards[i];
                  return Card(
                    child: ListTile(
                      title: Text(c.issue),
                      subtitle: Text('${c.pattern}\n${c.recommendation}'),
                      isThreeLine: true,
                    ),
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
