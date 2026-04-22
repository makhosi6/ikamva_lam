import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('shouldPrepareForCurrentConfig is true when no prepare state', () async {
    final shouldPrepare =
        await ModelPreparePrefs.shouldPrepareForCurrentConfig();
    expect(shouldPrepare, isTrue);
  });

  test('markPrepareDoneForCurrentConfig records done/url/timestamp', () async {
    await ModelPreparePrefs.markPrepareDoneForCurrentConfig();

    expect(await ModelPreparePrefs.isPrepareDone(), isTrue);
    expect(
      await ModelPreparePrefs.preparedModelUrl(),
      ModelPrepareConfig.networkUrl,
    );
    expect(await ModelPreparePrefs.preparedAt(), isNotNull);
  });

  test('clearPrepareDone removes done/url/timestamp', () async {
    await ModelPreparePrefs.markPrepareDoneForCurrentConfig();
    await ModelPreparePrefs.clearPrepareDone();

    expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
    expect(await ModelPreparePrefs.preparedModelUrl(), isNull);
    expect(await ModelPreparePrefs.preparedAt(), isNull);
  });
}
