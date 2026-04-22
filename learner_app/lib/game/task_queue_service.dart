import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../config/learner_content_policy.dart';
import '../data/task_record_repository.dart';
import '../db/app_database.dart';
import '../db/seed.dart';
import '../domain/skill_id.dart';
import '../domain/task_source.dart';
import '../domain/task_type.dart';
import '../domain/tasks/cloze_payload.dart';
import '../domain/tasks/pronunciation_intonation_payload.dart';
import '../domain/tasks/read_aloud_payload.dart';
import '../domain/tasks/task_normalizer.dart';
import '../domain/tasks/task_payload_validators.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../llm/llm_output_filters.dart';
import '../prompts/prompt_compliance.dart';
import '../prompts/prompt_composer.dart';
import '../prompts/prompt_slots.dart';
import '../safety/child_friendly_content_gate.dart';
import 'task_content_hash.dart';

/// Pre-fills SQLite with model-generated tasks (TASKS §8.1, §8.6).
class TaskQueueService {
  TaskQueueService(this._db);

  final IkamvaDatabase _db;

  static final _uuid = Uuid();
  static final _normalizer = TaskNormalizer();
  static const _minTopicTasks = 10;
  static const _maxTopicTasks = 20;

  static String? lastFillError;

  /// Count of **AI-authored** rows for [topic] (generated or prior-model cache).
  Future<int> countTopicCandidates(String topic) async {
    final rows = await (_db.select(_db.taskRecords)
          ..where((t) => t.topic.equals(topic))
          ..where(
            (t) => t.source.isIn([
              TaskSource.generated.storageValue,
              TaskSource.cachedGenerated.storageValue,
            ]),
          ))
        .get();
    return rows.length;
  }

  Future<bool> _hashExists(String topic, String hash) async {
    final hit = await (_db.select(_db.taskRecords)
          ..where((t) => t.topic.equals(topic))
          ..where((t) => t.contentHash.equals(hash)))
        .getSingleOrNull();
    return hit != null;
  }

  Future<void> ensureForQuest(Quest quest) async {
    if (quest.topic.isEmpty) return;
    final topicOk =
        await ChildFriendlyContentGate.evaluateTopicPhrase(quest.topic);
    if (!topicOk.ok) {
      lastFillError = 'topic_failed_safety:${topicOk.violations.join(",")}';
      developer.log(
        'TaskQueueService: quest topic failed safety — ${topicOk.violations}',
        name: 'TaskQueueService',
      );
      return;
    }
    try {
      await _fill(quest);
    } on Object catch (e, st) {
      lastFillError = '$e';
      developer.log('TaskQueueService: $e', error: e, stackTrace: st);
    }
  }

  Future<void> _fill(Quest quest) async {
    final topic = quest.topic;
    var count = await countTopicCandidates(topic);
    if (count >= _minTopicTasks) return;
    for (var i = 0;
        i < 18 && count < _minTopicTasks && count < _maxTopicTasks;
        i++) {
      final phase = i % 3;
      var added = false;
      if (phase == 1) {
        added = await _tryGenerateReadAloud(quest);
      } else if (phase == 2) {
        added = await _tryGeneratePronunciation(quest);
      }
      if (!added) {
        added = await _tryGenerateOrFallbackCloze(quest);
      }
      count = await countTopicCandidates(topic);
    }
  }

  Future<bool> _tryGenerateOrFallbackCloze(Quest quest) async {
    final topic = quest.topic;
    final slots = PromptSlots(
      level: quest.level,
      topic: topic,
      skill: SkillId.vocabulary.storageValue,
      difficultyStep: '${min(quest.maxDifficultyStep, 2)}',
    );
    try {
      final prompt = await PromptComposer().composeGenerationPrompt(
        TaskType.cloze,
        slots,
      );
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: ModelBoundPrompt(prompt)),
      );
      if (isEmptyComplianceObject(raw.text)) {
        await _maybeInsertFallback(quest);
        return false;
      }
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw.text);
      final map = _normalizer.normalizeJson(TaskType.cloze, span);
      if (map == null) {
        await _maybeInsertFallback(quest);
        return false;
      }
      late final ClozePayload cloze;
      try {
        cloze = ClozePayload.fromJson(map);
      } on Object {
        await _maybeInsertFallback(quest);
        return false;
      }
      final issues = TaskPayloadValidators.validateCloze(cloze, quest.level);
      if (issues.isNotEmpty) {
        await _maybeInsertFallback(quest);
        return false;
      }
      final payloadJson = jsonEncode(cloze.toJson());
      if (!await _payloadPassesChildSafety(payloadJson)) {
        await _maybeInsertFallback(quest);
        return false;
      }
      final hash = contentHashForClozePayloadJson(payloadJson);
      if (hash != null && await _hashExists(topic, hash)) {
        return false;
      }
      final id = 'gen-${_uuid.v4()}';
      await _db.into(_db.taskRecords).insert(
            TaskRecordsCompanion.insert(
              id: id,
              taskType: TaskType.cloze.storageValue,
              skillId: SkillId.vocabulary.storageValue,
              difficulty: 1,
              topic: topic,
              payloadJson: payloadJson,
              source: TaskSource.generated.storageValue,
              contentHash: Value(hash),
              createdAt: DateTime.now().toUtc(),
            ),
          );
      return true;
    } on Object catch (e) {
      lastFillError = '$e';
      await _maybeInsertFallback(quest);
      return false;
    }
  }

  Future<bool> _tryGenerateReadAloud(Quest quest) async {
    final topic = quest.topic;
    final slots = PromptSlots(
      level: quest.level,
      topic: topic,
      skill: SkillId.readAloud.storageValue,
      difficultyStep: '${min(quest.maxDifficultyStep, 2)}',
    );
    try {
      final prompt = await PromptComposer().composeGenerationPrompt(
        TaskType.readAloud,
        slots,
      );
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: ModelBoundPrompt(prompt)),
      );
      if (isEmptyComplianceObject(raw.text)) return false;
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw.text);
      final map = _normalizer.normalizeJson(TaskType.readAloud, span);
      if (map == null) return false;
      late final ReadAloudPayload payload;
      try {
        payload = ReadAloudPayload.fromJson(map);
      } on Object {
        return false;
      }
      final issues = TaskPayloadValidators.validateReadAloud(payload, quest.level);
      if (issues.isNotEmpty) return false;
      final payloadJson = jsonEncode(payload.toJson());
      if (!await _payloadPassesChildSafety(payloadJson)) return false;
      final hash = contentHashForReadAloudPayloadJson(payloadJson);
      if (hash != null && await _hashExists(topic, hash)) return false;
      await _db.into(_db.taskRecords).insert(
            TaskRecordsCompanion.insert(
              id: 'gen-${_uuid.v4()}',
              taskType: TaskType.readAloud.storageValue,
              skillId: SkillId.readAloud.storageValue,
              difficulty: 1,
              topic: topic,
              payloadJson: payloadJson,
              source: TaskSource.generated.storageValue,
              contentHash: Value(hash),
              createdAt: DateTime.now().toUtc(),
            ),
          );
      return true;
    } on Object catch (e) {
      lastFillError = '$e';
      return false;
    }
  }

  Future<bool> _tryGeneratePronunciation(Quest quest) async {
    final topic = quest.topic;
    final slots = PromptSlots(
      level: quest.level,
      topic: topic,
      skill: SkillId.pronunciationIntonation.storageValue,
      difficultyStep: '${min(quest.maxDifficultyStep, 2)}',
    );
    try {
      final prompt = await PromptComposer().composeGenerationPrompt(
        TaskType.pronunciationIntonation,
        slots,
      );
      final raw = await LlmService.instance.generate(
        LlmGenerateRequest(prompt: ModelBoundPrompt(prompt)),
      );
      if (isEmptyComplianceObject(raw.text)) return false;
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw.text);
      final map = _normalizer.normalizeJson(TaskType.pronunciationIntonation, span);
      if (map == null) return false;
      late final PronunciationIntonationPayload payload;
      try {
        payload = PronunciationIntonationPayload.fromJson(map);
      } on Object {
        return false;
      }
      final issues =
          TaskPayloadValidators.validatePronunciationIntonation(payload, quest.level);
      if (issues.isNotEmpty) return false;
      final payloadJson = jsonEncode(payload.toJson());
      if (!await _payloadPassesChildSafety(payloadJson)) return false;
      final hash = contentHashForPronunciationPayloadJson(payloadJson);
      if (hash != null && await _hashExists(topic, hash)) return false;
      await _db.into(_db.taskRecords).insert(
            TaskRecordsCompanion.insert(
              id: 'gen-${_uuid.v4()}',
              taskType: TaskType.pronunciationIntonation.storageValue,
              skillId: SkillId.pronunciationIntonation.storageValue,
              difficulty: 1,
              topic: topic,
              payloadJson: payloadJson,
              source: TaskSource.generated.storageValue,
              contentHash: Value(hash),
              createdAt: DateTime.now().toUtc(),
            ),
          );
      return true;
    } on Object catch (e) {
      lastFillError = '$e';
      return false;
    }
  }

  Future<bool> _payloadPassesChildSafety(String payloadJson) async {
    final v =
        await ChildFriendlyContentGate.evaluateJsonPayloadString(payloadJson);
    if (v.ok) return true;
    developer.log(
      'TaskQueueService: payload failed child-friendly gate → ${v.violations}',
      name: 'TaskQueueService',
    );
    return false;
  }

  Future<void> _maybeInsertFallback(Quest quest) async {
    if (!LearnerContentPolicy.allowDevSeed) return;
    await _insertFallback(quest);
  }

  Future<void> _insertFallback(Quest quest) async {
    final pick =
        kDevSeedFallbackTemplateTaskIds[Random().nextInt(
          kDevSeedFallbackTemplateTaskIds.length,
        )];
    final src = await TaskRecordRepository(_db).getById(pick);
    if (src == null) return;
    final id = 'fb-${_uuid.v4()}';
    await TaskRecordRepository(_db).insert(
      TaskRecordsCompanion.insert(
        id: id,
        taskType: src.taskType,
        skillId: src.skillId,
        difficulty: src.difficulty,
        topic: quest.topic,
        payloadJson: src.payloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
