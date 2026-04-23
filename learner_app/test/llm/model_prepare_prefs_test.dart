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

  test('markPrepareDoneForCurrentConfig records done/fingerprint/timestamp',
      () async {
    await ModelPreparePrefs.markPrepareDoneForCurrentConfig();

    expect(await ModelPreparePrefs.isPrepareDone(), isTrue);
    expect(
      await ModelPreparePrefs.preparedInstallFingerprint(),
      ModelPrepareConfig.modelInstallFingerprint,
    );
    expect(await ModelPreparePrefs.preparedAt(), isNotNull);
  });

  test('clearPrepareDone removes done/fingerprint/timestamp', () async {
    await ModelPreparePrefs.markPrepareDoneForCurrentConfig();
    await ModelPreparePrefs.clearPrepareDone();

    expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
    expect(await ModelPreparePrefs.preparedInstallFingerprint(), isNull);
    expect(await ModelPreparePrefs.preparedAt(), isNull);
  });
}
