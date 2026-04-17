import 'package:drift/drift.dart';

import '../data/attempt_repository.dart';
import '../data/session_repository.dart';
import '../db/app_database.dart';

/// Raised when [SessionController.acquireTaskSlot] cannot reserve another
/// task under quest or practice limits (TASKS §4.2).
class SessionLimitExceeded implements Exception {
  SessionLimitExceeded(this.reason);

  /// `max_tasks` or `time_limit`.
  final String reason;

  @override
  String toString() => 'SessionLimitExceeded($reason)';
}

/// Owns the active learning session: persistence, attempt [sessionId], and
/// enforcement of quest `maxTasks` / `sessionTimeLimitSec` (or practice overrides).
///
/// Call [acquireTaskSlot] before presenting each task (including the first).
class SessionController {
  SessionController(
    IkamvaDatabase db, {
    DateTime Function()? clock,
  })  : _sessions = SessionRepository(db),
        _attempts = AttemptRepository(db),
        _clock = clock ?? DateTime.now;

  final SessionRepository _sessions;
  final AttemptRepository _attempts;
  final DateTime Function() _clock;

  Session? _active;
  Quest? _limitQuest;
  int? _practiceMaxTasks;
  int? _practiceTimeLimitSec;
  int _tasksConsumed = 0;
  int _idNonce = 0;

  /// Current open session row, or null if none or after [endSession].
  Session? get currentSession => _active;

  String? get activeSessionId => _active?.id;

  /// How many task slots [acquireTaskSlot] has committed (for pause / resume).
  int get reservedTaskSlotCount => _tasksConsumed;

  int? get _effectiveMaxTasks =>
      _limitQuest?.maxTasks ?? _practiceMaxTasks;

  int? get _effectiveTimeLimitSec =>
      _limitQuest?.sessionTimeLimitSec ?? _practiceTimeLimitSec;

  void _assertIdle() {
    if (_active != null) {
      throw StateError(
        'A session is already active; call endSession() before starting another.',
      );
    }
  }

  void _resetLimits() {
    _limitQuest = null;
    _practiceMaxTasks = null;
    _practiceTimeLimitSec = null;
    _tasksConsumed = 0;
  }

  String _newId(String prefix) {
    _idNonce += 1;
    return '$prefix-${_clock().microsecondsSinceEpoch}-$_idNonce';
  }

  /// Starts a session bound to [quest] (limits from the quest row).
  Future<Session> startForQuest(Quest quest) async {
    _assertIdle();
    final id = _newId('sess');
    await _sessions.insert(
      SessionsCompanion.insert(
        id: id,
        questId: Value(quest.id),
        startedAt: _clock().toUtc(),
      ),
    );
    _active = await _sessions.getById(id);
    _limitQuest = quest;
    _practiceMaxTasks = null;
    _practiceTimeLimitSec = null;
    _tasksConsumed = 0;
    await _persistBaselineAccuracy();
    return _active!;
  }

  /// Attaches to an existing open session row (e.g. after app pause / resume).
  ///
  /// [tasksAlreadyReserved] must match [reservedTaskSlotCount] from when
  /// state was persisted.
  Future<void> resumeOpenQuestSession({
    required Session session,
    required Quest quest,
    required int tasksAlreadyReserved,
  }) async {
    _assertIdle();
    if (session.endedAt != null) {
      throw StateError('Cannot resume a session that already ended');
    }
    if (session.questId != quest.id) {
      throw StateError('Quest id does not match session');
    }
    _active = session;
    _limitQuest = quest;
    _practiceMaxTasks = null;
    _practiceTimeLimitSec = null;
    _tasksConsumed = tasksAlreadyReserved;
  }

  /// Practice mode: optional [maxTasks] / [timeLimitSec] mirror quest caps.
  Future<Session> startPractice({
    int? maxTasks,
    int? timeLimitSec,
  }) async {
    _assertIdle();
    final id = _newId('sess');
    await _sessions.insert(
      SessionsCompanion.insert(
        id: id,
        startedAt: _clock().toUtc(),
      ),
    );
    _active = await _sessions.getById(id);
    _limitQuest = null;
    _practiceMaxTasks = maxTasks;
    _practiceTimeLimitSec = timeLimitSec;
    _tasksConsumed = 0;
    await _persistBaselineAccuracy();
    return _active!;
  }

  Future<void> _persistBaselineAccuracy() async {
    final s = _active;
    if (s == null) return;
    final baseline = await _attempts.rollingAccuracyOverallBefore(
      beforeExclusive: s.startedAt,
    );
    if (baseline == null) return;
    await _sessions.update(
      s.id,
      SessionsCompanion(baselineAccuracy: Value(baseline)),
    );
    _active = await _sessions.getById(s.id);
  }

  bool _exceedsTaskCap(int countAfterThisSlot) {
    final cap = _effectiveMaxTasks;
    if (cap == null) return false;
    return countAfterThisSlot > cap;
  }

  bool _isTimeExpired() {
    final limit = _effectiveTimeLimitSec;
    if (limit == null || limit <= 0) return false;
    final start = _active?.startedAt;
    if (start == null) return true;
    final elapsed = _clock().toUtc().difference(start).inSeconds;
    return elapsed >= limit;
  }

  /// Reserves one task slot under active caps. Call once per task shown.
  void acquireTaskSlot() {
    final s = _active;
    if (s == null) throw StateError('No active session');

    final next = _tasksConsumed + 1;
    if (_exceedsTaskCap(next)) {
      throw SessionLimitExceeded('max_tasks');
    }
    if (_isTimeExpired()) {
      throw SessionLimitExceeded('time_limit');
    }
    _tasksConsumed = next;
  }

  /// Whether another task could be shown without exceeding caps right now.
  bool get canAcquireAnotherTask {
    if (_active == null) return false;
    final next = _tasksConsumed + 1;
    if (_exceedsTaskCap(next)) return false;
    if (_isTimeExpired()) return false;
    return true;
  }

  /// Inserts an attempt tied to [activeSessionId]. Fails if there is no session.
  Future<Attempt> addAttempt({
    required String taskId,
    required String learnerAnswerJson,
    required bool correct,
    required bool usedHint,
    int hintSteps = 0,
    int? latencyMs,
  }) async {
    final s = _active;
    if (s == null) throw StateError('No active session');

    if (_isTimeExpired()) {
      throw SessionLimitExceeded('time_limit');
    }

    final id = _newId('att');
    await _attempts.insert(
      AttemptsCompanion.insert(
        id: id,
        taskId: taskId,
        sessionId: s.id,
        learnerAnswerJson: learnerAnswerJson,
        correct: correct,
        usedHint: usedHint,
        hintSteps: Value(hintSteps),
        latencyMs: Value(latencyMs),
        timestamp: _clock().toUtc(),
      ),
    );
    return (await _attempts.getById(id))!;
  }

  /// Closes the session, writes [Session.endedAt] and aggregate stats from attempts.
  Future<Session> endSession() async {
    final s = _active;
    if (s == null) throw StateError('No active session');

    final attempts = await _attempts.listForSession(s.id);
    final distinctTasks = attempts.map((a) => a.taskId).toSet().length;
    final total = attempts.length;
    final correct = attempts.where((a) => a.correct).length;
    final hints = attempts.where((a) => a.usedHint).length;

    final accuracy = total == 0 ? null : correct / total;
    final hintRate = total == 0 ? null : hints / total;

    await _sessions.update(
      s.id,
      SessionsCompanion(
        endedAt: Value(_clock().toUtc()),
        tasksCompleted: Value(distinctTasks),
        accuracy: Value(accuracy),
        hintRate: Value(hintRate),
      ),
    );

    _active = null;
    _resetLimits();

    return (await _sessions.getById(s.id))!;
  }
}
