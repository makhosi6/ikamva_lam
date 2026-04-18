import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/quest_repository.dart';
import '../../db/app_database.dart';
import '../../state/database_scope.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

class TeacherQuestEditorScreen extends StatefulWidget {
  const TeacherQuestEditorScreen({super.key});

  @override
  State<TeacherQuestEditorScreen> createState() =>
      _TeacherQuestEditorScreenState();
}

class _TeacherQuestEditorScreenState extends State<TeacherQuestEditorScreen> {
  final _uuid = Uuid();
  final _topic = TextEditingController(text: 'school');
  final _level = TextEditingController(text: 'A1');
  final _maxStep = TextEditingController(text: '3');
  final _maxTasks = TextEditingController(text: '8');

  @override
  void dispose() {
    _topic.dispose();
    _level.dispose();
    _maxStep.dispose();
    _maxTasks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = DatabaseScope.of(context);
    final id = 'quest-${_uuid.v4()}';
    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(days: 14));
    await QuestRepository(db).insert(
      QuestsCompanion.insert(
        id: id,
        topic: _topic.text.trim().toLowerCase(),
        level: _level.text.trim().toUpperCase(),
        maxDifficultyStep: int.tryParse(_maxStep.text.trim()) ?? 3,
        sessionTimeLimitSec: const Value.absent(),
        maxTasks: Value(int.tryParse(_maxTasks.text.trim()) ?? 8),
        startsAt: now,
        endsAt: end,
        isActive: const Value(true),
      ),
    );
    if (!mounted) return;
    final code = id.replaceAll('-', '').substring(0, 8).toUpperCase();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quest saved'),
        content: Text('Pairing / quest code for learners: $code\n(Full id: $id)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'New quest', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _topic, decoration: const InputDecoration(labelText: 'Topic')),
              TextField(controller: _level, decoration: const InputDecoration(labelText: 'Level (A1, A2…)')),
              TextField(controller: _maxStep, decoration: const InputDecoration(labelText: 'Max difficulty step')),
              TextField(controller: _maxTasks, decoration: const InputDecoration(labelText: 'Max tasks per session')),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save quest')),
            ],
          ),
        ),
      ),
    );
  }
}
