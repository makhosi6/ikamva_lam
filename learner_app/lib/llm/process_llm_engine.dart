import 'dart:io';
import 'dart:isolate';

import 'llm_engine.dart';
import 'llm_exceptions.dart';
import 'llm_generate_request.dart';
import 'llm_output_filters.dart';

/// Runs `llama-cli` in a **synchronous** block — call from an isolate (§6.7).
class ProcessLlmEngine implements LlmEngine {
  ProcessLlmEngine({
    required this.cliPath,
    required this.modelPath,
  });

  final String cliPath;
  final String modelPath;
  bool _loaded = false;

  @override
  Future<void> ensureLoaded() async {
    if (!File(cliPath).existsSync()) {
      throw LlmUnavailableException('CLI not found: $cliPath');
    }
    if (!File(modelPath).existsSync()) {
      throw LlmUnavailableException('GGUF not found: $modelPath');
    }
    _loaded = true;
  }

  @override
  Future<String> generate(LlmGenerateRequest request) async {
    if (!_loaded) await ensureLoaded();
    final cli = cliPath;
    final model = modelPath;
    final prompt = request.prompt;
    final maxTokens = request.maxTokens ?? 120;
    final contextSize = request.contextSize ?? 768;
    final stops = request.stopSequences;
    return Isolate.run(
      () => runLlamaCliSync(
        cliPath: cli,
        modelPath: model,
        prompt: prompt,
        maxTokens: maxTokens,
        contextSize: contextSize,
        stopSequences: stops,
      ),
    );
  }

  @override
  void dispose() {
    _loaded = false;
  }
}

/// Top-level for [Isolate.run] (TASKS §6.7).
String runLlamaCliSync({
  required String cliPath,
  required String modelPath,
  required String prompt,
  required int maxTokens,
  required int contextSize,
  List<String> stopSequences = const [],
}) {
  final result = Process.runSync(
    cliPath,
    [
      '-m',
      modelPath,
      '-p',
      prompt,
      '-n',
      '$maxTokens',
      '-c',
      '$contextSize',
      '--no-display-prompt',
    ],
    includeParentEnvironment: true,
    runInShell: false,
  );
  if (result.exitCode != 0) {
    final err = result.stderr.toString().trim();
    throw LlmResourceException(
      err.isEmpty ? 'llama-cli exited ${result.exitCode}' : err,
    );
  }
  var text = result.stdout.toString();
  for (final stop in stopSequences) {
    if (stop.isEmpty) continue;
    final i = text.indexOf(stop);
    if (i >= 0) {
      text = text.substring(0, i);
    }
  }
  return LlmOutputFilters.takeThroughFirstBalancedJson(text);
}
