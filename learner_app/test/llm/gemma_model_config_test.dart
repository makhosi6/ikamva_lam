import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/gemma_model_config.dart';

void main() {
  test('isWebOnlyMediaPipeTaskUrl detects -web.task variants', () {
    expect(
      GemmaModelConfig.isWebOnlyMediaPipeTaskUrl(
        'https://x/y/model-web.task?download=1',
      ),
      isTrue,
    );
    expect(
      GemmaModelConfig.isWebOnlyMediaPipeTaskUrl('https://x/y/model.task'),
      isFalse,
    );
  });

  test('filenameFromPathOrUrl handles URL/path/empty', () {
    expect(
      GemmaModelConfig.filenameFromPathOrUrl(
        'https://huggingface.co/a/b/c/model.task?download=1',
      ),
      'model.task',
    );
    expect(
      GemmaModelConfig.filenameFromPathOrUrl(
        '/tmp/models/gemma-4-E2B-it.litertlm',
      ),
      'gemma-4-E2B-it.litertlm',
    );
    expect(GemmaModelConfig.filenameFromPathOrUrl('  '), '');
  });

  test('pluginUninstallCandidateIdsFor includes file and basename', () {
    final ids = GemmaModelConfig.pluginUninstallCandidateIdsFor(
      'https://host/path/gemma-4-E2B-it.litertlm',
    );
    expect(ids, contains('gemma-4-E2B-it.litertlm'));
    expect(ids, contains('gemma-4-E2B-it'));
  });

  test('fileKindForPath maps known model extensions', () {
    expect(GemmaModelConfig.fileKindForPath('model.task'), InstallModelFileKind.task);
    expect(
      GemmaModelConfig.fileKindForPath('model.litertlm'),
      InstallModelFileKind.litertlm,
    );
    expect(
      GemmaModelConfig.fileKindForPath('weights.bin'),
      InstallModelFileKind.binary,
    );
  });
}
