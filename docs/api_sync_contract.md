# Summary sync API (TASKS §14.1)

Optional HTTPS endpoint for **compressed JSON summaries only** (no raw attempts).

## `POST /v1/summaries`

- **Headers:** `Content-Type: application/json`, `Authorization: Bearer <token>` (team-defined), `Idempotency-Key: <uuid>` (client-generated per payload).
- **Body:** same shape as `ExportSummaryService.buildSummaryJson()` in the learner app (`learner_app/lib/analytics/export_summary_service.dart`): learner id, session totals, `top_weak_skills`, `last_session`.
- **Responses:** `202 Accepted` with `{ "received": true }` when queued; `200 OK` when stored. Repeat with same idempotency key must not duplicate rows server-side.

## Client behaviour

- Rows live in `sync_outbox` (Drift). `SyncOutboxFlushService` POSTs each `payload_json` when `IKAMVA_SYNC_URL` is set at compile time or a base URL is passed in code.
- Backoff: increment `retry_count`, store `last_error`; retry on next app resume or manual “Try sync” from **Debug stats** (debug builds).

This document is sufficient for a mocked server during judging; production auth is out of scope for the hackathon MVP.
