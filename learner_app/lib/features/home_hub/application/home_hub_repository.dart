import '../../../data/quest_repository.dart';
import '../../../db/app_database.dart';
import '../../../db/seed.dart';
import '../../../hub/daily_topics_service.dart';
import '../../../hub/hub_daily_topic_progress.dart';
import '../domain/hub_payload.dart';

/// Loads hub content (topics, progress, quest template metadata).
class HomeHubRepository {
  Future<HubPayload> loadPayload(IkamvaDatabase db) async {
    final offers = await DailyTopicsService.loadOffersForToday();
    final done = await HubDailyTopicProgress.completedForDay(
      DailyTopicsService.calendarDayKeyLocal(),
    );
    final template = await QuestRepository(db).getById(kSeedQuestId);
    final level = (template?.level ?? 'A1').trim();
    final maxTasks = template?.maxTasks ?? 24;
    return HubPayload(
      offers,
      done,
      questLevel: level.isEmpty ? 'A1' : level,
      questMaxTasks: maxTasks < 1 ? 24 : maxTasks,
    );
  }
}
