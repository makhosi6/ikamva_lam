import 'package:drift/drift.dart';

@DataClassName('LearnerProfile')
class LearnerProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get homeLanguageCode => text().nullable()();
  TextColumn get pairedTeacherCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Quest')
class Quests extends Table {
  TextColumn get id => text()();
  TextColumn get topic => text()();
  TextColumn get level => text()();
  IntColumn get maxDifficultyStep => integer()();
  IntColumn get sessionTimeLimitSec => integer().nullable()();
  IntColumn get maxTasks => integer().nullable()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TaskRecord')
class TaskRecords extends Table {
  TextColumn get id => text()();
  TextColumn get taskType => text()();
  TextColumn get skillId => text()();
  IntColumn get difficulty => integer()();
  TextColumn get topic => text()();
  TextColumn get payloadJson => text()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Session')
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get questId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get tasksCompleted => integer().withDefault(const Constant(0))();
  RealColumn get accuracy => real().nullable()();
  RealColumn get hintRate => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Attempt')
class Attempts extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get sessionId => text()();
  TextColumn get learnerAnswerJson => text()();
  BoolColumn get correct => boolean()();
  BoolColumn get usedHint => boolean()();
  IntColumn get hintSteps => integer().withDefault(const Constant(0))();
  IntColumn get latencyMs => integer().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncOutboxEntry')
class SyncOutboxEntries extends Table {
  @override
  String get tableName => 'sync_outbox';

  TextColumn get id => text()();
  TextColumn get payloadJson => text()();
  TextColumn get entityType => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
