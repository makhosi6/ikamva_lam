import 'package:drift/drift.dart';

import '../db/app_database.dart';

class InsightCardRepository {
  InsightCardRepository(this._db);

  final IkamvaDatabase _db;

  Future<void> insert(InsightCardsCompanion row) =>
      _db.into(_db.insightCards).insert(row);

  Future<List<InsightCard>> listForLearner(String learnerId) {
    return (_db.select(_db.insightCards)
          ..where((t) => t.learnerId.equals(learnerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }
}
