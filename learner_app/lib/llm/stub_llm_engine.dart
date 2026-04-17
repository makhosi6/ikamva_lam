import 'dart:convert';

import 'llm_engine.dart';
import 'llm_generate_request.dart';

/// Deterministic offline backend for CI and missing-native setups (TASKS §6.5).
class StubLlmEngine implements LlmEngine {
  bool _ready = false;

  @override
  Future<void> ensureLoaded() async {
    _ready = true;
  }

  @override
  Future<String> generate(LlmGenerateRequest request) async {
    if (!_ready) await ensureLoaded();
    final snippet = request.prompt.length > 120
        ? request.prompt.substring(0, 120)
        : request.prompt;
    return jsonEncode({
      'stub': true,
      'echo': snippet,
      'max_tokens': request.maxTokens,
      'context': request.contextSize,
    });
  }

  @override
  void dispose() {
    _ready = false;
  }
}
