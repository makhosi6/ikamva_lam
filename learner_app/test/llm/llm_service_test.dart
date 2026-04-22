import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/llm_exceptions.dart';
import 'package:ikamva_lam/llm/llm_generate_request.dart';
import 'package:ikamva_lam/llm/llm_service.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('generate throws LlmUnavailableException when model URL is not compiled in', () async {
    if (ModelPrepareConfig.hasNetworkModelUrl) {
      // Local/CI builds with --dart-define-from-file may set URL; skip assertion.
      return;
    }
    final settings = SettingsStore();
    await settings.load();
    LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.configure(settings);
    await expectLater(
      LlmService.instance.generate(
        const LlmGenerateRequest(prompt: ModelBoundPrompt('hello')),
      ),
      throwsA(isA<LlmUnavailableException>()),
    );
  });

  test('tryOpenGenerateStream throws when model URL is not compiled in', () async {
    if (ModelPrepareConfig.hasNetworkModelUrl) {
      return;
    }
    final settings = SettingsStore();
    await settings.load();
    LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.configure(settings);
    await expectLater(
      LlmService.instance.tryOpenGenerateStream(
        const LlmGenerateRequest(prompt: ModelBoundPrompt('hello')),
      ),
      throwsA(isA<LlmUnavailableException>()),
    );
  });
}
