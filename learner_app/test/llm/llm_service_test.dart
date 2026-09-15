import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/llm_exceptions.dart';
import 'package:ikamva_lam/llm/llm_generate_request.dart';
import 'package:ikamva_lam/llm/llm_service.dart';
import 'package:ikamva_lam/llm/flutter_gemma_llm_engine.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await LlmService.instance.invalidateCachedEngine();
  });

  tearDown(() async {
    // This singleton is global in app runtime; avoid leaking state across tests.
    await LlmService.instance.invalidateCachedEngine();
  });

  test(
    'generate throws LlmUnavailableException on non-mobile host',
    () async {
      if (shouldUseFlutterGemmaEngine) {
        return;
      }
      final settings = SettingsStore();
      await settings.load();
      await LlmService.instance.invalidateCachedEngine();
      LlmService.instance.configure(settings);
      await expectLater(
        LlmService.instance.generate(
          const LlmGenerateRequest(prompt: ModelBoundPrompt('hello')),
        ),
        throwsA(isA<LlmUnavailableException>()),
      );
    },
  );

  test(
    'tryOpenGenerateStream throws on non-mobile host',
    () async {
      if (shouldUseFlutterGemmaEngine) {
        return;
      }
      final settings = SettingsStore();
      await settings.load();
      await LlmService.instance.invalidateCachedEngine();
      LlmService.instance.configure(settings);
      await expectLater(
        LlmService.instance.tryOpenGenerateStream(
          const LlmGenerateRequest(prompt: ModelBoundPrompt('hello')),
        ),
        throwsA(isA<LlmUnavailableException>()),
      );
    },
  );

  test('invalidateCachedEngine is safe and idempotent', () async {
    await LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.invalidateCachedEngine();
  });
}
