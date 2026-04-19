import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analytics/ikamva_analytics.dart';
import '../analytics/insight_job.dart';
import '../audio/tts_service.dart';
import '../data/attempt_repository.dart';
import '../metrics/metrics_store.dart';
import '../data/difficulty_state_repository.dart';
import '../data/quest_repository.dart';
import '../data/session_repository.dart';
import '../db/app_database.dart';
import '../db/seed.dart';
import '../domain/skill_id.dart';
import '../domain/task_type.dart';
import '../domain/tasks/cloze_payload.dart';
import '../domain/tasks/dialogue_choice_payload.dart';
import '../domain/tasks/match_payload.dart';
import '../domain/tasks/pronunciation_intonation_payload.dart';
import '../domain/tasks/read_aloud_payload.dart';
import '../domain/tasks/reorder_payload.dart';
import '../game/adaptive_difficulty_engine.dart';
import '../game/game_coordinator.dart';
import '../game/retry_policy.dart';
import '../game/rule_based_evaluator.dart';
import '../game/rule_hint_catalog.dart';
import '../game/session_controller.dart';
import '../game/task_queue_service.dart';
import '../hints/ai_hint_coordinator.dart';
import '../hub/daily_quest_ids.dart';
import '../hub/daily_topics_service.dart';
import '../hub/hub_daily_topic_progress.dart';
import '../state/database_scope.dart';
import '../state/game_pause_store.dart';
import '../state/settings_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';
import '../widgets/topic_illustration.dart';

class GameShellScreen extends StatefulWidget {
  const GameShellScreen({
    super.key,
    this.resume = false,
    this.hubTopic,
    this.hubDayKey,
  });

  final bool resume;

  /// Hub "Today's topics" — paired with [hubDayKey] (`yyyy-MM-dd`, local).
  final String? hubTopic;
  final String? hubDayKey;

  @override
  State<GameShellScreen> createState() => _GameShellScreenState();
}

class _GameShellScreenState extends State<GameShellScreen> {
  static const _evaluator = RuleBasedEvaluator();
  static const _analytics = IkamvaAnalytics();
  static const _difficultyEngine = AdaptiveDifficultyEngine();

  late IkamvaDatabase _db;
  late SessionController _session;
  late GameCoordinator _coordinator;
  late AttemptRepository _attemptRepo;
  late DifficultyStateRepository _difficultyRepo;
  late PerTaskRetryPolicy _retry;

  Quest? _quest;
  List<TaskRecord> _tasks = [];
  int _taskIndex = 0;

  int _difficultyStep = 1;
  bool _dbHintFirst = false;

  bool _loading = true;
  String? _error;

  TaskType? _taskType;
  String? _selectedChoice;
  List<int> _reorderOrder = [];
  ReorderPayload? _reorderPayload;
  List<int?> _matchRightForLeft = [];
  MatchPayload? _matchPayload;
  int? _matchPickLeft;
  int? _dialogueIndex;
  DialogueChoicePayload? _dialoguePayload;
  ReadAloudPayload? _readAloudPayload;
  bool _readAloudDone = false;
  int? _pronunciationIndex;
  PronunciationIntonationPayload? _pronunciationPayload;

  /// Vocabulary cloze: TTS word range in [cloze.sentence] (when the engine reports it).
  bool _ttsSpeaking = false;
  int? _ttsRangeStart;
  int? _ttsRangeEnd;

  int _hintSteps = 0;
  bool _usedHintThisTask = false;

  @override
  void initState() {
    super.initState();
    _retry = PerTaskRetryPolicy();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    unawaited(TtsService.instance.stop());
    super.dispose();
  }

  Future<void> _loadAdaptiveStateAndTasks() async {
    final quest = _quest!;
    final row = await _difficultyRepo.getRow(
      kSeedLearnerId,
      SkillId.vocabulary.storageValue,
      quest.id,
    );
    _difficultyStep = row?.step ?? 1;
    _dbHintFirst = row?.hintFirstMode ?? false;
    final list = await _coordinator.loadTasksForQuest(
      quest,
      maxDifficultyInclusive: _difficultyStep,
    );
    if (!mounted) return;
    setState(() {
      _tasks = list;
      if (_tasks.isNotEmpty && _taskIndex >= _tasks.length) {
        _taskIndex = _tasks.length - 1;
      }
      if (_tasks.isNotEmpty) {
        _retry.resetForNewTask();
        _resetTaskUi();
      }
    });
  }

  Future<void> _afterAttemptAdapt(TaskRecord task) async {
    final quest = _quest!;
    final roll = await _attemptRepo.rollingAccuracyForSkill(task.skillId);
    final row = await _difficultyRepo.getRow(
      kSeedLearnerId,
      task.skillId,
      quest.id,
    );
    final step = row?.step ?? 1;
    final hint = row?.hintFirstMode ?? false;
    final adj = _difficultyEngine.recommend(
      rollingAccuracy: roll,
      currentStep: step,
      maxStep: quest.maxDifficultyStep,
      hintFirstActive: hint,
    );
    final next = _difficultyEngine.apply(
      adjustment: adj,
      currentStep: step,
      hintFirstMode: hint,
      maxStep: quest.maxDifficultyStep,
    );
    await _difficultyRepo.upsert(
      learnerId: kSeedLearnerId,
      skillId: task.skillId,
      questKey: quest.id,
      step: next.step,
      hintFirstMode: next.hintFirstMode,
    );
    final prevStep = _difficultyStep;
    _difficultyStep = next.step;
    _dbHintFirst = next.hintFirstMode;
    if (next.step != prevStep) {
      await _loadAdaptiveStateAndTasks();
    } else if (mounted) {
      setState(() {});
    }
    if (!mounted || adj == DifficultyAdjustment.hold) return;
    if (adj == DifficultyAdjustment.harder) {
      _showGameSnackBar('Nice streak — slightly harder tasks unlocked.');
    } else if (adj == DifficultyAdjustment.easier) {
      _showGameSnackBar('Taking it a bit easier for now.');
    } else if (adj == DifficultyAdjustment.enableHintFirst) {
      _showGameSnackBar('Try the hint before checking your answer.');
    }
  }

  Quest _syntheticQuestFromTemplate(
    Quest template,
    String id,
    String topic,
  ) {
    final t = DailyQuestIds.normalizeTopicToken(topic);
    return Quest(
      id: id,
      topic: t,
      level: template.level,
      maxDifficultyStep: template.maxDifficultyStep,
      sessionTimeLimitSec: template.sessionTimeLimitSec,
      maxTasks: template.maxTasks,
      startsAt: template.startsAt,
      endsAt: template.endsAt,
      isActive: template.isActive,
    );
  }

  Quest? _questFromPause(Quest template, String questId) {
    if (questId == kSeedQuestId) return template;
    final parsed = DailyQuestIds.tryParse(questId);
    if (parsed == null) return null;
    return _syntheticQuestFromTemplate(template, questId, parsed.$2);
  }

  Future<void> _bootstrap() async {
    _db = DatabaseScope.of(context);
    _session = SessionController(_db);
    _coordinator = GameCoordinator(_db);
    _attemptRepo = AttemptRepository(_db);
    _difficultyRepo = DifficultyStateRepository(_db);

    final template = await QuestRepository(_db).getById(kSeedQuestId);
    if (!mounted) return;
    if (template == null) {
      setState(() {
        _loading = false;
        _error = 'No sample quest in database.';
      });
      return;
    }

    final dayKey = DailyQuestIds.normalizeDayKey(widget.hubDayKey);
    final topicParam = widget.hubTopic != null && widget.hubTopic!.trim().isNotEmpty
        ? DailyQuestIds.normalizeTopicToken(widget.hubTopic!)
        : null;
    final hubOk = dayKey != null && topicParam != null;

    if (widget.resume) {
      final snap = await GamePauseStore.load();
      if (snap != null) {
        final resolved = _questFromPause(template, snap.questId);
        if (resolved != null) {
          final existing = await SessionRepository(_db).getById(snap.sessionId);
          if (existing != null &&
              existing.endedAt == null &&
              snap.questId == resolved.id) {
            try {
              _quest = resolved;
              await TaskQueueService(_db).ensureForQuest(resolved);
              await _session.resumeOpenQuestSession(
                session: existing,
                quest: resolved,
                tasksAlreadyReserved: snap.reservedTaskSlots,
              );
              await _loadAdaptiveStateAndTasks();
              if (_tasks.isEmpty) {
                setState(() {
                  _loading = false;
                  _error = 'No tasks for this quest.';
                });
                return;
              }
              _taskIndex = snap.taskIndex.clamp(0, _tasks.length - 1);
              _retry.resetForNewTask();
              _resetTaskUi();
              _maybeHintFirstNudge();
              await GamePauseStore.clear();
              setState(() => _loading = false);
              _scheduleTtsStem();
              return;
            } on Object {
              await GamePauseStore.clear();
            }
          }
        } else {
          await GamePauseStore.clear();
        }
      }
    }

    await GamePauseStore.clear();

    final Quest quest;
    if (!widget.resume && hubOk) {
      quest = _syntheticQuestFromTemplate(
        template,
        DailyQuestIds.make(dayKey, topicParam),
        topicParam,
      );
    } else {
      quest = template;
    }

    _quest = quest;
    await TaskQueueService(_db).ensureForQuest(quest);

    try {
      await _session.startForQuest(quest);
      await _loadAdaptiveStateAndTasks();
      if (_tasks.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No tasks for this quest.';
        });
        return;
      }
      _session.acquireTaskSlot();
      _retry.resetForNewTask();
      _resetTaskUi();
      _maybeHintFirstNudge();
    } on SessionLimitExceeded catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not start session: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _scheduleTtsStem();
  }

  void _scheduleTtsStem() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final settings = SettingsScope.of(context);
      if (!settings.ttsEnabled) return;
      final t = _tasks[_taskIndex];
      final type = TaskType.tryParse(t.taskType);
      String? line;
      switch (type) {
        case TaskType.cloze:
          line = ClozePayload.tryParseJsonString(t.payloadJson)?.sentence;
          break;
        case TaskType.reorder:
          line = ReorderPayload.tryParseJsonString(t.payloadJson)?.sentenceText();
          break;
        case TaskType.match:
          line = 'Match each word on the left with the right column.';
          break;
        case TaskType.dialogueChoice:
          final d = DialogueChoicePayload.tryParseJsonString(t.payloadJson);
          line = d == null ? null : '${d.context} ${d.question}';
          break;
        case TaskType.readAloud:
          final r = ReadAloudPayload.tryParseJsonString(t.payloadJson);
          if (r != null) {
            line = r.instructionEn != null && r.instructionEn!.isNotEmpty
                ? '${r.instructionEn} ${r.displayText}'
                : r.displayText;
          }
          break;
        case TaskType.pronunciationIntonation:
          final p =
              PronunciationIntonationPayload.tryParseJsonString(t.payloadJson);
          if (p != null) {
            line = p.referenceLine ?? p.question;
          }
          break;
        default:
          break;
      }
      if (line == null || line.isEmpty) return;

      final vocabCloze = type == TaskType.cloze &&
          SkillId.tryParse(t.skillId) == SkillId.vocabulary;

      if (vocabCloze) {
        if (!mounted) return;
        setState(() {
          _ttsSpeaking = true;
          _ttsRangeStart = null;
          _ttsRangeEnd = null;
        });
        await TtsService.instance.speak(
          line.replaceAll('___', ' blank '),
          onProgress: (start, end) {
            if (!mounted) return;
            setState(() {
              _ttsRangeStart = start;
              _ttsRangeEnd = end;
            });
          },
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _ttsSpeaking = false;
              _ttsRangeStart = null;
              _ttsRangeEnd = null;
            });
          },
        );
        return;
      }

      await TtsService.instance.speak(line.replaceAll('___', ' blank '));
    });
  }

  void _maybeHintFirstNudge() {
    if (!_dbHintFirst || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showGameSnackBar(
        'Hint-first mode: skim the hint before you choose an answer.',
      );
    });
  }

  /// Floating snackbar above the bottom **Check answer** bar + system inset.
  void _showGameSnackBar(String message, {Duration? duration}) {
    if (!mounted) return;
    final bottom =
        MediaQuery.paddingOf(context).bottom + 76;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        duration: duration ?? const Duration(seconds: 4),
        content: Text(message),
      ),
    );
  }

  void _resetTaskUi() {
    unawaited(TtsService.instance.stop());
    _ttsSpeaking = false;
    _ttsRangeStart = null;
    _ttsRangeEnd = null;
    _selectedChoice = null;
    _reorderOrder = [];
    _reorderPayload = null;
    _matchRightForLeft = [];
    _matchPayload = null;
    _matchPickLeft = null;
    _dialogueIndex = null;
    _dialoguePayload = null;
    _readAloudPayload = null;
    _readAloudDone = false;
    _pronunciationIndex = null;
    _pronunciationPayload = null;
    _hintSteps = 0;
    _usedHintThisTask = false;
    _prepareTaskKindState();
    setState(() {});
  }

  void _prepareTaskKindState() {
    if (_tasks.isEmpty || _taskIndex >= _tasks.length) {
      _taskType = null;
      return;
    }
    final t = _tasks[_taskIndex];
    _taskType = TaskType.tryParse(t.taskType);
    switch (_taskType) {
      case TaskType.reorder:
        final p = ReorderPayload.tryParseJsonString(t.payloadJson);
        if (p != null) {
          _reorderPayload = p;
          _reorderOrder = List.of(p.correctOrder);
          if (_reorderOrder.length >= 2) {
            final a = _reorderOrder[0];
            _reorderOrder[0] = _reorderOrder[1];
            _reorderOrder[1] = a;
          }
        }
        break;
      case TaskType.match:
        final p = MatchPayload.tryParseJsonString(t.payloadJson);
        if (p != null) {
          _matchPayload = p;
          _matchRightForLeft = List<int?>.filled(p.left.length, null);
          _matchPickLeft = null;
        }
        break;
      case TaskType.dialogueChoice:
        _dialoguePayload =
            DialogueChoicePayload.tryParseJsonString(t.payloadJson);
        break;
      case TaskType.readAloud:
        _readAloudPayload = ReadAloudPayload.tryParseJsonString(t.payloadJson);
        _readAloudDone = false;
        break;
      case TaskType.pronunciationIntonation:
        _pronunciationPayload =
            PronunciationIntonationPayload.tryParseJsonString(t.payloadJson);
        _pronunciationIndex = null;
        break;
      default:
        break;
    }
  }

  String _skillLabel(String skillId) => skillId.replaceAll('_', ' ');

  ClozePayload? get _cloze {
    if (_tasks.isEmpty || _taskIndex >= _tasks.length) return null;
    return ClozePayload.tryParseJsonString(_tasks[_taskIndex].payloadJson);
  }

  String? _learnerJsonForSubmit() {
    final task = _tasks[_taskIndex];
    final type = TaskType.tryParse(task.taskType);
    switch (type) {
      case TaskType.cloze:
        if (_selectedChoice == null) return null;
        return jsonEncode({'choice': _selectedChoice});
      case TaskType.reorder:
        if (_reorderOrder.isEmpty) return null;
        return jsonEncode({'order': _reorderOrder});
      case TaskType.match:
        if (_matchRightForLeft.isEmpty ||
            _matchRightForLeft.any((e) => e == null)) {
          return null;
        }
        final pairs = <List<int>>[];
        for (var i = 0; i < _matchRightForLeft.length; i++) {
          pairs.add([i, _matchRightForLeft[i]!]);
        }
        return jsonEncode({'pairs': pairs});
      case TaskType.dialogueChoice:
        if (_dialogueIndex == null) return null;
        return jsonEncode({'index': _dialogueIndex});
      case TaskType.readAloud:
        if (!_readAloudDone) return null;
        return jsonEncode({'completed': true});
      case TaskType.pronunciationIntonation:
        if (_pronunciationIndex == null) return null;
        return jsonEncode({'index': _pronunciationIndex});
      default:
        return null;
    }
  }

  bool get _hasRequiredAnswer {
    return _learnerJsonForSubmit() != null;
  }

  Future<void> _submit() async {
    if (!_retry.canSubmit) return;
    final json = _learnerJsonForSubmit();
    if (json == null) return;

    final task = _tasks[_taskIndex];
    final result = _evaluator.evaluate(task, json);

    _retry.recordSubmission();
    final attemptNo = _retry.submissionCount;

    try {
      await _session.addAttempt(
        taskId: task.id,
        learnerAnswerJson: json,
        correct: result.correct,
        usedHint: _usedHintThisTask,
        hintSteps: _hintSteps,
      );
    } on SessionLimitExceeded {
      if (!mounted) return;
      _showGameSnackBar('Time limit reached.');
      await _finishSession();
      return;
    }

    await _afterAttemptAdapt(task);

    _analytics.recordAttemptOutcome(
      taskId: task.id,
      skillId: task.skillId,
      correct: result.correct,
      usedHint: _usedHintThisTask,
    );

    if (!mounted) return;

    if (result.correct) {
      await _goNextTask();
      return;
    }

    if (!result.correct && attemptNo == 2) {
      await AiHintCoordinator.showForWrongAnswer(
        context,
        task: task,
        wrongAnswerJson: json,
      );
      if (!mounted) return;
    }

    if (_retry.canSubmit) {
      if (!result.correct && attemptNo == 1) {
        if (!mounted) return;
        _showGameSnackBar(
          '${ruleHintForFirstWrong(task.skillId)} Try another answer.',
        );
      } else if (!result.correct && attemptNo > 1) {
        if (!mounted) return;
        _showGameSnackBar('Not quite — try again.');
      }
      setState(() {
        _selectedChoice = null;
        _dialogueIndex = null;
        _pronunciationIndex = null;
        _readAloudDone = false;
      });
      return;
    }

    _showGameSnackBar('Moving on — review this one later.');
    await _goNextTask();
  }

  Future<void> _goNextTask() async {
    final next = _taskIndex + 1;
    if (next >= _tasks.length) {
      await _finishSession();
      return;
    }
    _taskIndex = next;
    _retry.resetForNewTask();
    _resetTaskUi();
    try {
      _session.acquireTaskSlot();
    } on SessionLimitExceeded {
      if (!mounted) return;
      _showGameSnackBar('Session limit reached.');
      await _finishSession();
      return;
    }
    _maybeHintFirstNudge();
    if (mounted) setState(() {});
    _scheduleTtsStem();
  }

  Future<void> _recordHubTopicProgress() async {
    final q = _quest;
    if (q == null) return;
    await HubDailyTopicProgress.markCompleted(
      DailyTopicsService.calendarDayKeyLocal(),
      q.topic,
    );
  }

  Future<void> _finishSession() async {
    try {
      final ended = await _session.endSession();
      await _recordHubTopicProgress();
      final attempts =
          await AttemptRepository(_db).listForSession(ended.id);
      final hints = attempts.where((a) => a.usedHint).length;
      final correct = attempts.where((a) => a.correct).length;
      await MetricsStore.recordSession(
        attempts: attempts.length,
        hints: hints,
        correct: correct,
      );
      await GamePauseStore.clear();
      if (!mounted) return;
      unawaited(InsightJob.runAfterSession(_db, ended.id));
      context.go('/session-summary', extra: ended.id);
    } on StateError {
      if (!mounted) return;
      context.go('/home');
    }
  }

  Future<void> _pauseSession() async {
    final sid = _session.activeSessionId;
    final q = _quest;
    if (sid == null || q == null) return;
    await GamePauseStore.save(
      GamePauseSnapshot(
        sessionId: sid,
        questId: q.id,
        taskIndex: _taskIndex,
        reservedTaskSlots: _session.reservedTaskSlotCount,
      ),
    );
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave session?'),
        content: const Text(
          'Use Pause from the app bar to resume later. End session now to save attempts and open the summary.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final ended = await _session.endSession();
      await _recordHubTopicProgress();
      final attempts =
          await AttemptRepository(_db).listForSession(ended.id);
      final hints = attempts.where((a) => a.usedHint).length;
      final correct = attempts.where((a) => a.correct).length;
      await MetricsStore.recordSession(
        attempts: attempts.length,
        hints: hints,
        correct: correct,
      );
      await GamePauseStore.clear();
      if (!mounted) return;
      unawaited(InsightJob.runAfterSession(_db, ended.id));
      context.go('/session-summary', extra: ended.id);
    } on StateError {
      await GamePauseStore.clear();
      if (!mounted) return;
      context.go('/home');
    }
  }

  void _onHint() {
    final task = _tasks[_taskIndex];
    final type = TaskType.tryParse(task.taskType);
    var hintLine = 'Take a slow second look before you choose.';
    switch (type) {
      case TaskType.cloze:
        final cloze = _cloze;
        if (cloze == null) return;
        final settings = SettingsScope.of(context);
        final code = settings.hintLanguageCode.toLowerCase();
        String? h;
        switch (code) {
          case 'xh':
            h = cloze.hintXh ?? cloze.hintEn;
            break;
          case 'zu':
            h = cloze.hintZu ?? cloze.hintEn;
            break;
          case 'af':
            h = cloze.hintAf ?? cloze.hintEn;
            break;
          default:
            h = cloze.hintEn;
        }
        hintLine = h ?? 'Pick the word that fits the blank.';
        break;
      case TaskType.reorder:
        hintLine =
            'Read the mixed line aloud, then tap arrows until it sounds right.';
        break;
      case TaskType.match:
        hintLine = 'Tap a word on the left, then its partner on the right.';
        break;
      case TaskType.dialogueChoice:
        hintLine =
            'Reread the short story, then pick the answer that fits best.';
        break;
      case TaskType.readAloud:
        hintLine = 'Read the line aloud, then match the calm example.';
        final r = _readAloudPayload;
        if (r != null) {
          final settings = SettingsScope.of(context);
          final code = settings.hintLanguageCode.toLowerCase();
          switch (code) {
            case 'xh':
              hintLine = r.hintXh ?? r.hintEn ?? hintLine;
              break;
            case 'zu':
              hintLine = r.hintZu ?? r.hintEn ?? hintLine;
              break;
            case 'af':
              hintLine = r.hintAf ?? r.hintEn ?? hintLine;
              break;
            default:
              hintLine = r.hintEn ?? hintLine;
          }
        }
        break;
      case TaskType.pronunciationIntonation:
        hintLine = 'Listen for stress and tune before you pick.';
        final p = _pronunciationPayload;
        if (p != null) {
          final settings = SettingsScope.of(context);
          final code = settings.hintLanguageCode.toLowerCase();
          switch (code) {
            case 'xh':
              hintLine = p.hintXh ?? p.hintEn ?? hintLine;
              break;
            case 'zu':
              hintLine = p.hintZu ?? p.hintEn ?? hintLine;
              break;
            case 'af':
              hintLine = p.hintAf ?? p.hintEn ?? hintLine;
              break;
            default:
              hintLine = p.hintEn ?? hintLine;
          }
        }
        break;
      default:
        break;
    }
    setState(() {
      _usedHintThisTask = true;
      _hintSteps++;
    });
    _showGameSnackBar(hintLine);
    if (SettingsScope.of(context).ttsEnabled) {
      unawaited(
        TtsService.instance.speak(hintLine.replaceAll('___', ' blank ')),
      );
    }
  }

  void _swapReorder(int posA, int posB) {
    final tmp = _reorderOrder[posA];
    _reorderOrder[posA] = _reorderOrder[posB];
    _reorderOrder[posB] = tmp;
    setState(() {});
  }

  Widget _buildReorderBody(ThemeData theme) {
    final p = _reorderPayload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Put the words in order', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (var pos = 0; pos < p.tokens.length; pos++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: pos > 0 ? () => _swapReorder(pos, pos - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: pos < p.tokens.length - 1
                      ? () => _swapReorder(pos, pos + 1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    p.tokens[_reorderOrder[pos]],
                    style: theme.textTheme.titleMedium,
                    softWrap: true,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  int? _matchLeftIndexForRight(int rightIndex) {
    for (var i = 0; i < _matchRightForLeft.length; i++) {
      if (_matchRightForLeft[i] == rightIndex) return i;
    }
    return null;
  }

  Widget _buildMatchBody(ThemeData theme) {
    final p = _matchPayload!;
    final scheme = theme.colorScheme;
    final ik = theme.extension<IkamvaColors>() ?? IkamvaColors.light;
    final n = p.left.length;

    Widget pairBadge(int oneBased, Color accent, Color onAccent) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$oneBased',
          style: theme.textTheme.labelLarge?.copyWith(
            color: onAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    ButtonStyle matchButtonStyle({
      required bool selected,
      required bool paired,
      required Color? pairAccent,
      required Color? pairSurfaceTint,
    }) {
      final borderColor = selected
          ? scheme.primary
          : (paired && pairAccent != null ? pairAccent : scheme.outlineVariant);
      final width = selected || paired ? 2.5 : 1.0;
      return FilledButton.styleFrom(
        backgroundColor: selected
            ? scheme.primaryContainer
            : (paired && pairSurfaceTint != null
                ? Color.alphaBlend(
                    pairSurfaceTint,
                    scheme.surfaceContainerHighest,
                  )
                : null),
        side: BorderSide(color: borderColor, width: width),
        elevation: selected ? 1.5 : 0,
        shadowColor: selected ? scheme.primary.withValues(alpha: 0.35) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Match pairs', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          _matchPickLeft == null
              ? 'Tap a word on the left, then tap its match on the right.'
              : 'Now tap the matching word on the right.',
          style: theme.textTheme.bodyMedium?.copyWith(color: ik.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Left', style: theme.textTheme.labelLarge),
                  for (var i = 0; i < p.left.length; i++)
                    Builder(
                      builder: (context) {
                        final pairedRight = _matchRightForLeft[i];
                        final paired = pairedRight != null;
                        final accent = ikamvaMatchPairAccent(context, i, n);
                        final surfaceTint =
                            ikamvaMatchPairSurfaceTint(context, i, n);
                        final onAccent =
                            ThemeData.estimateBrightnessForColor(accent) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black87;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: FilledButton.tonal(
                            style: matchButtonStyle(
                              selected: _matchPickLeft == i,
                              paired: paired,
                              pairAccent: paired ? accent : null,
                              pairSurfaceTint: paired ? surfaceTint : null,
                            ),
                            onPressed: () => setState(() => _matchPickLeft = i),
                            child: Row(
                              children: [
                                if (paired) ...[
                                  pairBadge(i + 1, accent, onAccent),
                                  const SizedBox(width: 10),
                                ] else if (_matchPickLeft == i) ...[
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: 22,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    p.left[i],
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (paired) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.link_rounded,
                                    size: 20,
                                    color: accent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Right', style: theme.textTheme.labelLarge),
                  for (var j = 0; j < p.right.length; j++)
                    Builder(
                      builder: (context) {
                        final leftIdx = _matchLeftIndexForRight(j);
                        final paired = leftIdx != null;
                        final accent = paired
                            ? ikamvaMatchPairAccent(context, leftIdx, n)
                            : null;
                        final surfaceTint = paired
                            ? ikamvaMatchPairSurfaceTint(context, leftIdx, n)
                            : null;
                        final onAccent = accent != null &&
                                ThemeData.estimateBrightnessForColor(
                                      accent,
                                    ) ==
                                    Brightness.dark
                            ? Colors.white
                            : Colors.black87;
                        final pickLeft = _matchPickLeft;
                        final canLink = pickLeft != null;
                        VoidCallback? onRightPressed;
                        if (canLink) {
                          onRightPressed = () {
                            setState(() {
                              for (var i = 0;
                                  i < _matchRightForLeft.length;
                                  i++) {
                                if (_matchRightForLeft[i] == j) {
                                  _matchRightForLeft[i] = null;
                                }
                              }
                              _matchRightForLeft[pickLeft] = j;
                              _matchPickLeft = null;
                            });
                          };
                        } else if (paired) {
                          // Stay visually "on" for completed pairs; no-op until a left is chosen.
                          onRightPressed = () {};
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: FilledButton.tonal(
                            style: matchButtonStyle(
                              selected: false,
                              paired: paired,
                              pairAccent: accent,
                              pairSurfaceTint: surfaceTint,
                            ),
                            onPressed: onRightPressed,
                            child: Row(
                              children: [
                                if (paired) ...[
                                  pairBadge(leftIdx + 1, accent!, onAccent),
                                  const SizedBox(width: 10),
                                ] else if (canLink) ...[
                                  Icon(
                                    Icons.add_link_rounded,
                                    size: 22,
                                    color: scheme.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    p.right[j],
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _playReadAloudReference() async {
    final p = _readAloudPayload;
    if (p == null) return;
    final line = p.displayText;
    if (line.isEmpty) return;
    await TtsService.instance.speak(line);
  }

  Future<void> _playPronunciationReference() async {
    final p = _pronunciationPayload;
    if (p == null) return;
    final line = p.referenceLine ?? p.question;
    if (line.isEmpty) return;
    await TtsService.instance.speak(line);
  }

  Widget _buildReadAloudBody(ThemeData theme) {
    final p = _readAloudPayload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Read aloud', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (p.instructionEn != null && p.instructionEn!.trim().isNotEmpty) ...[
          Text(
            p.instructionEn!,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          p.displayText,
          style: theme.textTheme.headlineSmall?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Hear example'),
          onPressed: () => unawaited(_playReadAloudReference()),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => setState(() => _readAloudDone = true),
          child: const Text('I read this aloud'),
        ),
      ],
    );
  }

  Widget _buildPronunciationBody(ThemeData theme) {
    final p = _pronunciationPayload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Listen & choose', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(p.question, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (p.referenceLine != null && p.referenceLine!.trim().isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.hearing_rounded),
            label: const Text('Play reference'),
            onPressed: () => unawaited(_playPronunciationReference()),
          ),
        if (p.referenceLine != null && p.referenceLine!.trim().isNotEmpty)
          const SizedBox(height: 12),
        for (var i = 0; i < p.options.length; i++)
          ListTile(
            onTap: () => setState(() => _pronunciationIndex = i),
            leading: Icon(
              _pronunciationIndex == i
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(p.options[i]),
          ),
      ],
    );
  }

  Widget _buildDialogueBody(ThemeData theme) {
    final p = _dialoguePayload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose the best reply', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(p.context, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(p.question, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var i = 0; i < p.options.length; i++)
          ListTile(
            onTap: () => setState(() => _dialogueIndex = i),
            leading: Icon(
              _dialogueIndex == i
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(p.options[i].text),
          ),
      ],
    );
  }

  Widget _buildClozeBody(BuildContext context, ClozePayload cloze) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;
    final vocab = SkillId.tryParse(_tasks[_taskIndex].skillId) ==
        SkillId.vocabulary;
    if (vocab) {
      return _buildVocabularyClozeBody(context, theme, ik, cloze);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Fill in the blank', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(
          cloze.sentence,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in cloze.options)
              ChoiceChip(
                label: Text(opt),
                selected: _selectedChoice == opt,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedChoice = opt);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildVocabularyClozeBody(
    BuildContext context,
    ThemeData theme,
    IkamvaColors ik,
    ClozePayload cloze,
  ) {
    final scheme = theme.colorScheme;
    final chipsHint = Text(
      'Tap the word that fills the gap',
      style: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.68),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Fill the gap',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_ttsSpeaking) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.graphic_eq_rounded,
                size: 22,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: ik.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _ttsSpeaking
                  ? ik.accentSun.withValues(alpha: 0.9)
                  : scheme.outline.withValues(alpha: 0.22),
              width: _ttsSpeaking ? 2.5 : 1,
            ),
            boxShadow: [
              if (_ttsSpeaking)
                BoxShadow(
                  color: ik.accentSun.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Text.rich(
            TextSpan(children: _ikamvaClozeStemSpans(
              sentence: cloze.sentence,
              theme: theme,
              ik: ik,
              hiStart: _ttsRangeStart,
              hiEnd: _ttsRangeEnd,
            )),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        chipsHint,
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in cloze.options)
              ChoiceChip(
                label: Text(opt),
                selected: _selectedChoice == opt,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedChoice = opt);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveTask(ThemeData theme, ClozePayload? cloze) {
    switch (_taskType) {
      case TaskType.cloze:
        if (cloze != null) return _buildClozeBody(context, cloze);
        return const Text('Invalid cloze task.');
      case TaskType.reorder:
        if (_reorderPayload != null) return _buildReorderBody(theme);
        return const Text('Invalid reorder task.');
      case TaskType.match:
        if (_matchPayload != null) return _buildMatchBody(theme);
        return const Text('Invalid match task.');
      case TaskType.dialogueChoice:
        if (_dialoguePayload != null) return _buildDialogueBody(theme);
        return const Text('Invalid dialogue task.');
      case TaskType.readAloud:
        if (_readAloudPayload != null) return _buildReadAloudBody(theme);
        return const Text('Invalid read-aloud task.');
      case TaskType.pronunciationIntonation:
        if (_pronunciationPayload != null) {
          return _buildPronunciationBody(theme);
        }
        return const Text('Invalid pronunciation task.');
      case null:
        return const Text('Unknown task type.');
    }
  }

  String _taskTitle() {
    switch (_taskType) {
      case TaskType.reorder:
        return 'Reorder';
      case TaskType.match:
        return 'Match';
      case TaskType.dialogueChoice:
        return 'Dialogue';
      case TaskType.cloze:
        if (_tasks.isNotEmpty &&
            SkillId.tryParse(_tasks[_taskIndex].skillId) ==
                SkillId.vocabulary) {
          return 'Vocabulary';
        }
        return 'Cloze';
      case TaskType.readAloud:
        return 'Read aloud';
      case TaskType.pronunciationIntonation:
        return 'Pronunciation';
      case null:
        return 'Task';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const IkamvaAppBarTitle(title: 'Practice', logoHeight: 30),
        ),
        body: Center(child: Text(_error!)),
      );
    }

    final quest = _quest!;
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : (_taskIndex + 1) / total;
    final cloze = _cloze;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
        ),
        title: IkamvaAppBarTitle(title: quest.topic, logoHeight: 30),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: 'Pause',
            onPressed: _pauseSession,
          ),
          TextButton(
            onPressed: _onHint,
            child: const Text('Hint'),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.primary,
                backgroundColor: ik.accentSun.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'Task ${_taskIndex + 1} of $total · ${_skillLabel(_tasks[_taskIndex].skillId)} · '
                'Difficulty up to step $_difficultyStep / ${quest.maxDifficultyStep}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TopicIllustration(topic: quest.topic),
              const SizedBox(height: 16),
              Text(
                _taskTitle(),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildActiveTask(theme, cloze),
                ),
              ),
              FilledButton(
                onPressed:
                    (_hasRequiredAnswer && _retry.canSubmit) ? _submit : null,
                child: const Text('Check answer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stem text for vocabulary cloze: underlined [___] gap, optional TTS word highlight.
List<InlineSpan> _ikamvaClozeStemSpans({
  required String sentence,
  required ThemeData theme,
  required IkamvaColors ik,
  int? hiStart,
  int? hiEnd,
}) {
  final len = sentence.length;
  var h0 = -1;
  var h1 = -1;
  if (hiStart != null && hiEnd != null && hiEnd > hiStart) {
    h0 = hiStart.clamp(0, len);
    h1 = hiEnd.clamp(0, len);
    if (h1 < h0) h1 = h0;
  }

  final base = theme.textTheme.headlineSmall!.copyWith(
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: theme.colorScheme.onSurface,
  );
  final blankStyle = base.copyWith(
    color: theme.colorScheme.primary,
    decoration: TextDecoration.underline,
    decorationThickness: 2,
    decorationColor: theme.colorScheme.primary.withValues(alpha: 0.45),
  );

  TextStyle withHi(TextStyle s, int segStart, int segEnd) {
    if (h0 < 0 || h1 <= h0) return s;
    if (segEnd <= h0 || segStart >= h1) return s;
    return s.copyWith(
      backgroundColor: ik.accentSun.withValues(alpha: 0.38),
    );
  }

  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in RegExp(r'___').allMatches(sentence)) {
    if (m.start > last) {
      final a = last;
      final b = m.start;
      spans.add(TextSpan(
        text: sentence.substring(a, b),
        style: withHi(base, a, b),
      ));
    }
    final a = m.start;
    final b = m.end;
    spans.add(TextSpan(
      text: '___',
      style: withHi(blankStyle, a, b),
    ));
    last = m.end;
  }
  if (last < len) {
    spans.add(TextSpan(
      text: sentence.substring(last),
      style: withHi(base, last, len),
    ));
  }
  return spans;
}

/// Distinct accent per match row (left index) for borders and badges.
Color ikamvaMatchPairAccent(BuildContext context, int leftIndex, int n) {
  final scheme = Theme.of(context).colorScheme;
  if (n <= 0) return scheme.primary;
  final h = (leftIndex * 137.5080469) % 360.0;
  return HSVColor.fromAHSV(1, h, 0.55, 0.45).toColor();
}

Color ikamvaMatchPairSurfaceTint(BuildContext context, int leftIndex, int n) {
  return ikamvaMatchPairAccent(context, leftIndex, n).withValues(alpha: 0.2);
}

