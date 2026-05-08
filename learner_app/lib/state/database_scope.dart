import 'package:flutter/material.dart';

import '../db/app_database.dart';

class DatabaseScope extends InheritedWidget {
  const DatabaseScope({
    super.key,
    required this.database,
    required super.child,
  });

  final IkamvaDatabase database;

  static IkamvaDatabase of(BuildContext context, {bool listen = true}) {
    final DatabaseScope? scope = listen
        ? context.dependOnInheritedWidgetOfExactType<DatabaseScope>()
        : context.getInheritedWidgetOfExactType<DatabaseScope>();
    assert(scope != null, 'DatabaseScope missing');
    return scope!.database;
  }

  @override
  bool updateShouldNotify(DatabaseScope oldWidget) =>
      database != oldWidget.database;
}
