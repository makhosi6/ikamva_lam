import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/quest_repository.dart';
import 'db/app_database.dart';
import 'db/seed.dart';
import 'game/task_queue_service.dart';
import 'llm/llm_service.dart';
import 'router/app_router.dart';
import 'state/database_scope.dart';
import 'state/settings_scope.dart';
import 'state/settings_store.dart';
import 'theme/app_theme.dart';

class IkamvaApp extends StatefulWidget {
  const IkamvaApp({
    super.key,
    required this.settings,
    required this.database,
  });

  final SettingsStore settings;
  final IkamvaDatabase database;

  @override
  State<IkamvaApp> createState() => _IkamvaAppState();
}

class _IkamvaAppState extends State<IkamvaApp> with WidgetsBindingObserver {
  late final GoRouter _router = createAppRouter(widget.settings);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _topUpQueue();
    }
  }

  Future<void> _topUpQueue() async {
    final quest = await QuestRepository(widget.database).getById(kSeedQuestId);
    if (quest != null) {
      await TaskQueueService(widget.database).ensureForQuest(quest);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LlmService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DatabaseScope(
      database: widget.database,
      child: SettingsScope(
        notifier: widget.settings,
        child: MaterialApp.router(
          title: 'Ikamva Lam',
          debugShowCheckedModeBanner: false,
          theme: buildIkamvaTheme(brightness: Brightness.light),
          routerConfig: _router,
        ),
      ),
    );
  }
}
