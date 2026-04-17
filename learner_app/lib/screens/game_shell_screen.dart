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
import '../domain/tasks/reorder_payload.dart';
import '../game/adaptive_difficulty_engine.dart';
import '../game/game_coordinator.dart';
import '../game/retry_policy.dart';
import '../game/rule_based_evaluator.dart';
import '../game/rule_hint_catalog.dart';
import '../game/session_controller.dart';
import '../game/task_queue_service.dart';
import '../hints/ai_hint_coordinator.dart';
import '../state/database_scope.dart';
import '../state/game_pause_store.dart';
import '../state/settings_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';
import '../widgets/topic_illustration.dart';

class GameShellScreen extends StatefulWidget {
  const GameShellScreen({super.key, this.resume = false});

  final bool resume;

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

  int _hintSteps = 0;
  bool _usedHintThisTask = false;

  @override
  void initState() {
    super.initState();
    _retry = PerTaskRetryPolicy();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nice streak — slightly harder tasks unlocked.'),
        ),
      );
    } else if (adj == DifficultyAdjustment.easier) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taking it a bit easier for now.')),
      );
    } else if (adj == DifficultyAdjustment.enableHintFirst) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Try the hint before checking your answer.'),
        ),
      );
    }
  }

  Future<void> _bootstrap() async {
    _db = DatabaseScope.of(context);
    _session = SessionController(_db);
    _coordinator = GameCoordinator(_db);
    _attemptRepo = AttemptRepository(_db);
    _difficultyRepo = DifficultyStateRepository(_db);

    final quest = await QuestRepository(_db).getById(kSeedQuestId);
    if (!mounted) return;
    if (quest == null) {
      setState(() {
        _loading = false;
        _error = 'No sample quest in database.';
      });
      return;
    }
    _quest = quest;
    await TaskQueueService(_db).ensureForQuest(quest);

    if (widget.resume) {
      final snap = await GamePauseStore.load();
      if (snap != null && snap.questId == quest.id) {
        final existing = await SessionRepository(_db).getById(snap.sessionId);
        if (existing != null && existing.endedAt == null) {
          try {
            await _session.resumeOpenQuestSession(
              session: existing,
              quest: quest,
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
      }
    }

    await GamePauseStore.clear();
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
        default:
          break;
      }
      if (line != null && line.isNotEmpty) {
        await TtsService.instance.speak(line);
      }
    });
  }

  void _maybeHintFirstNudge() {
    if (!_dbHintFirst || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hint-first mode: skim the hint before you choose an answer.',
          ),
        ),
      );
    });
  }

  void _resetTaskUi() {
    _selectedChoice = null;
    _reorderOrder = [];
    _reorderPayload = null;
    _matchRightForLeft = [];
    _matchPayload = null;
    _matchPickLeft = null;
    _dialogueIndex = null;
    _dialoguePayload = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time limit reached.')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ruleHintForFirstWrong(task.skillId)} Try another answer.',
            ),
          ),
        );
      } else if (!result.correct && attemptNo > 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not quite — try again.')),
        );
      }
      setState(() {
        _selectedChoice = null;
        _dialogueIndex = null;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Moving on — review this one later.')),
    );
    await _goNextTask();
  }

  Future<void> _goNextTask() async {
    _taskIndex++;
    _retry.resetForNewTask();
    _resetTaskUi();
    if (_taskIndex >= _tasks.length) {
      await _finishSession();
      return;
    }
    try {
      _session.acquireTaskSlot();
    } on SessionLimitExceeded {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session limit reached.')),
      );
      await _finishSession();
      return;
    }
    _maybeHintFirstNudge();
    if (mounted) setState(() {});
    _scheduleTtsStem();
  }

  Future<void> _finishSession() async {
    try {
      final ended = await _session.endSession();
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
    String? text;
    switch (type) {
      case TaskType.cloze:
        final cloze = _cloze;
        if (cloze == null) return;
        final settings = SettingsScope.of(context);
        final code = settings.hintLanguageCode.toLowerCase();
        switch (code) {
          case 'xh':
            text = cloze.hintXh ?? cloze.hintEn;
            break;
          case 'zu':
            text = cloze.hintZu ?? cloze.hintEn;
            break;
          case 'af':
            text = cloze.hintAf ?? cloze.hintEn;
            break;
          default:
            text = cloze.hintEn;
        }
        text ??= 'Pick the word that fits the blank.';
        break;
      case TaskType.reorder:
        text = 'Read the mixed line aloud, then tap arrows until it sounds right.';
        break;
      case TaskType.match:
        text = 'Tap a word on the left, then its partner on the right.';
        break;
      case TaskType.dialogueChoice:
        text = 'Reread the short story, then pick the answer that fits best.';
        break;
      default:
        text = 'Take a slow second look before you choose.';
    }
    setState(() {
      _usedHintThisTask = true;
      _hintSteps++;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    if (SettingsScope.of(context).ttsEnabled) {
      unawaited(TtsService.instance.speak(text));
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
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMatchBody(ThemeData theme) {
    final p = _matchPayload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Match pairs', style: theme.textTheme.headlineSmall),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: _matchPickLeft == i
                              ? theme.colorScheme.primaryContainer
                              : null,
                        ),
                        onPressed: () => setState(() => _matchPickLeft = i),
                        child: Text(p.left[i]),
                      ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FilledButton.tonal(
                        onPressed: () {
                          if (_matchPickLeft == null) return;
                          setState(() {
                            for (var i = 0; i < _matchRightForLeft.length; i++) {
                              if (_matchRightForLeft[i] == j) {
                                _matchRightForLeft[i] = null;
                              }
                            }
                            _matchRightForLeft[_matchPickLeft!] = j;
                            _matchPickLeft = null;
                          });
                        },
                        child: Text(p.right[j]),
                      ),
                    ),
                ],
              ),
            ),
          ],
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

  Widget _buildClozeBody(ThemeData theme, ClozePayload cloze) {
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

  Widget _buildActiveTask(ThemeData theme, ClozePayload? cloze) {
    switch (_taskType) {
      case TaskType.cloze:
        if (cloze != null) return _buildClozeBody(theme, cloze);
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
        return 'Cloze';
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

