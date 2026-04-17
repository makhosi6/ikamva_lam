import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analytics/ikamva_analytics.dart';
import '../data/quest_repository.dart';
import '../data/session_repository.dart';
import '../db/app_database.dart';
import '../db/seed.dart';
import '../domain/tasks/cloze_payload.dart';
import '../game/game_coordinator.dart';
import '../game/retry_policy.dart';
import '../game/rule_based_evaluator.dart';
import '../game/session_controller.dart';
import '../state/database_scope.dart';
import '../state/game_pause_store.dart';
import '../state/settings_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

class GameShellScreen extends StatefulWidget {
  const GameShellScreen({super.key, this.resume = false});

  /// When true, restore from [GamePauseStore] if possible.
  final bool resume;

  @override
  State<GameShellScreen> createState() => _GameShellScreenState();
}

class _GameShellScreenState extends State<GameShellScreen> {
  static const _evaluator = RuleBasedEvaluator();
  static const _analytics = IkamvaAnalytics();

  late IkamvaDatabase _db;
  late SessionController _session;
  late GameCoordinator _coordinator;
  late PerTaskRetryPolicy _retry;

  Quest? _quest;
  List<TaskRecord> _tasks = [];
  int _taskIndex = 0;

  bool _loading = true;
  String? _error;

  String? _selectedChoice;
  int _hintSteps = 0;
  bool _usedHintThisTask = false;

  @override
  void initState() {
    super.initState();
    _retry = PerTaskRetryPolicy();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    _db = DatabaseScope.of(context);
    _session = SessionController(_db);
    _coordinator = GameCoordinator(_db);

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
            _tasks = await _coordinator.loadTasksForQuest(quest);
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
            await GamePauseStore.clear();
            setState(() => _loading = false);
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
      _tasks = await _coordinator.loadTasksForQuest(quest);
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
    } on SessionLimitExceeded catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not start session: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _resetTaskUi() {
    _selectedChoice = null;
    _hintSteps = 0;
    _usedHintThisTask = false;
  }

  String _skillLabel(String skillId) {
    return skillId.replaceAll('_', ' ');
  }

  ClozePayload? get _cloze {
    if (_tasks.isEmpty || _taskIndex >= _tasks.length) return null;
    final t = _tasks[_taskIndex];
    return ClozePayload.tryParseJsonString(t.payloadJson);
  }

  Future<void> _submit() async {
    final cloze = _cloze;
    if (cloze == null || _selectedChoice == null) return;
    if (!_retry.canSubmit) return;

    final task = _tasks[_taskIndex];
    final learnerJson = jsonEncode({'choice': _selectedChoice});
    final result = _evaluator.evaluate(task, learnerJson);

    _retry.recordSubmission();
    try {
      await _session.addAttempt(
        taskId: task.id,
        learnerAnswerJson: learnerJson,
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

    if (_retry.canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not quite — try again.')),
      );
      setState(() => _selectedChoice = null);
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
    if (mounted) setState(() {});
  }

  Future<void> _finishSession() async {
    try {
      final ended = await _session.endSession();
      await GamePauseStore.clear();
      if (!mounted) return;
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
      await GamePauseStore.clear();
      if (!mounted) return;
      context.go('/session-summary', extra: ended.id);
    } on StateError {
      await GamePauseStore.clear();
      if (!mounted) return;
      context.go('/home');
    }
  }

  void _onHint() {
    final cloze = _cloze;
    if (cloze == null) return;
    final settings = SettingsScope.of(context);
    final code = settings.hintLanguageCode.toLowerCase();
    String? text;
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
    setState(() {
      _usedHintThisTask = true;
      _hintSteps++;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    final cloze = _cloze!;
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : (_taskIndex + 1) / total;

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
                'Task ${_taskIndex + 1} of $total · ${_skillLabel(_tasks[_taskIndex].skillId)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Fill in the blank',
                style: theme.textTheme.headlineSmall,
              ),
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
              const Spacer(),
              FilledButton(
                onPressed: (_selectedChoice != null && _retry.canSubmit)
                    ? _submit
                    : null,
                child: const Text('Check answer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

