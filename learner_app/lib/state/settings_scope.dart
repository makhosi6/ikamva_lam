import 'package:flutter/material.dart';

import 'settings_store.dart';

class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({
    super.key,
    required SettingsStore super.notifier,
    required super.child,
  });

  static SettingsStore of(BuildContext context, {bool listen = true}) {
    final SettingsScope? scope = listen
        ? context.dependOnInheritedWidgetOfExactType<SettingsScope>()
        : context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing');
    return scope!.notifier!;
  }
}
