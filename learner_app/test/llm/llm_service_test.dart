import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/llm_generate_request.dart';
import 'package:ikamva_lam/llm/llm_service.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('generate uses stub when native paths absent', () async {
    final settings = SettingsStore();
    await settings.load();
    LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.configure(settings);
    final out = await LlmService.instance.generate(
      const LlmGenerateRequest(prompt: 'hello'),
    );
    expect(out, contains('"stub":true'));
    expect(out, contains('hello'));
  });

  test('tryOpenGenerateStream is null until an engine implements StreamingLlmCapability', () async {
    final settings = SettingsStore();
    await settings.load();
    LlmService.instance.invalidateCachedEngine();
    await LlmService.instance.configure(settings);
    final stream = await LlmService.instance.tryOpenGenerateStream(
      const LlmGenerateRequest(prompt: 'hello'),
    );
    expect(stream, isNull);
  });
}
