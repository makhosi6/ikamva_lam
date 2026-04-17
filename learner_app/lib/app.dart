import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'db/app_database.dart';
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

class _IkamvaAppState extends State<IkamvaApp> {
  late final GoRouter _router = createAppRouter(widget.settings);

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
