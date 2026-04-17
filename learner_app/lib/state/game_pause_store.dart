import 'package:shared_preferences/shared_preferences.dart';

/// Serializable pause state for the game shell (TASKS §4.5).
class GamePauseSnapshot {
  const GamePauseSnapshot({
    required this.sessionId,
    required this.questId,
    required this.taskIndex,
    required this.reservedTaskSlots,
  });

  final String sessionId;
  final String questId;

  /// Index into the coordinator task list for the task currently shown.
  final int taskIndex;

  /// Value to pass to [SessionController.resumeOpenQuestSession].
  final int reservedTaskSlots;
}

/// Persists minimal session resume metadata across navigation / app restarts.
class GamePauseStore {
  static const _kSession = 'game_pause_session_id';
  static const _kQuest = 'game_pause_quest_id';
  static const _kTaskIndex = 'game_pause_task_index';
  static const _kSlots = 'game_pause_reserved_slots';

  static Future<void> save(GamePauseSnapshot snapshot) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSession, snapshot.sessionId);
    await p.setString(_kQuest, snapshot.questId);
    await p.setInt(_kTaskIndex, snapshot.taskIndex);
    await p.setInt(_kSlots, snapshot.reservedTaskSlots);
  }

  static Future<GamePauseSnapshot?> load() async {
    final p = await SharedPreferences.getInstance();
    final sessionId = p.getString(_kSession);
    final questId = p.getString(_kQuest);
    if (sessionId == null || questId == null) return null;
    return GamePauseSnapshot(
      sessionId: sessionId,
      questId: questId,
      taskIndex: p.getInt(_kTaskIndex) ?? 0,
      reservedTaskSlots: p.getInt(_kSlots) ?? 0,
    );
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSession);
    await p.remove(_kQuest);
    await p.remove(_kTaskIndex);
    await p.remove(_kSlots);
  }
}
