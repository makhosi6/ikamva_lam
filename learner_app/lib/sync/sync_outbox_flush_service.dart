import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../data/sync_outbox_repository.dart';
import '../db/app_database.dart';

/// Optional summary flush when `IKAMVA_SYNC_URL` is set (TASKS §14.2 stub).
class SyncOutboxFlushService {
  SyncOutboxFlushService(this._db);

  final IkamvaDatabase _db;

  Future<int> flushPending({String? baseUrl}) async {
    final url = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : const String.fromEnvironment('IKAMVA_SYNC_URL', defaultValue: '');
    if (url.isEmpty) return 0;
    final uri = Uri.parse(url);
    final repo = SyncOutboxRepository(_db);
    final rows = await repo.listAll();
    var ok = 0;
    for (final row in rows) {
      try {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: row.payloadJson,
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          await repo.deleteById(row.id);
          ok++;
        } else {
          await repo.update(
            row.id,
            SyncOutboxEntriesCompanion(
              retryCount: Value(row.retryCount + 1),
              lastError: Value('HTTP ${res.statusCode}'),
            ),
          );
        }
      } on Object catch (e) {
        await repo.update(
          row.id,
          SyncOutboxEntriesCompanion(
            retryCount: Value(row.retryCount + 1),
            lastError: Value('$e'),
          ),
        );
      }
    }
    return ok;
  }
}
