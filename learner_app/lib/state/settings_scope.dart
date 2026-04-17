import 'package:flutter/material.dart';

import 'settings_store.dart';

class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({
    super.key,
    required SettingsStore super.notifier,
    required super.child,
  });

  static SettingsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing');
    return scope!.notifier!;
  }
}
