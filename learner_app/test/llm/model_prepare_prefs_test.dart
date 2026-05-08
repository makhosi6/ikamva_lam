import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/gemma4_ondevice_variant.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('shouldPrepareForFingerprint is true when no prepare state', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      Gemma4OnDeviceVariant.e2bBundled,
    );
    final shouldPrepare = await ModelPreparePrefs.shouldPrepareForFingerprint(fp);
    expect(shouldPrepare, isTrue);
  });

  test('markPrepareDone records done/fingerprint/timestamp', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      Gemma4OnDeviceVariant.e2bBundled,
    );
    await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

    expect(await ModelPreparePrefs.isPrepareDone(), isTrue);
    expect(
      await ModelPreparePrefs.preparedInstallFingerprint(),
      fp,
    );
    expect(await ModelPreparePrefs.preparedAt(), isNotNull);
  });

  test('clearPrepareDone removes done/fingerprint/timestamp', () async {
    final fp = ModelPrepareConfig.installFingerprint(
      Gemma4OnDeviceVariant.e4bNetwork,
    );
    await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);
    await ModelPreparePrefs.clearPrepareDone();

    expect(await ModelPreparePrefs.isPrepareDone(), isFalse);
    expect(await ModelPreparePrefs.preparedInstallFingerprint(), isNull);
    expect(await ModelPreparePrefs.preparedAt(), isNull);
  });
}
