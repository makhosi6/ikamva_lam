import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ikamva_lam/app.dart';
import 'package:ikamva_lam/db/database_connection.dart';
import 'package:ikamva_lam/state/settings_store.dart';

void main() {
  testWidgets('App loads welcome when onboarding incomplete', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.load();
    await tester.pumpWidget(
      IkamvaApp(settings: settings, database: openMemoryDatabase()),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Ikamva Lam'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
