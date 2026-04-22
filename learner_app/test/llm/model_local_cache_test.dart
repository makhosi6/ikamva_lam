import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/model_local_cache.dart';

void main() {
  test('isUsableCacheForUrl requires matching url and minimum size', () {
    expect(
      ModelLocalCache.isUsableCacheForUrl(
        url: 'https://a/x.task',
        metaJson: '{"url":"https://a/x.task","bytes":1048576}',
        fileLength: 1048576,
      ),
      isTrue,
    );
    expect(
      ModelLocalCache.isUsableCacheForUrl(
        url: 'https://a/x.task',
        metaJson: '{"url":"https://other/y.task","bytes":1048576}',
        fileLength: 1048576,
      ),
      isFalse,
    );
    expect(
      ModelLocalCache.isUsableCacheForUrl(
        url: 'https://a/x.task',
        metaJson: '{"url":"https://a/x.task","bytes":1048576}',
        fileLength: 500,
      ),
      isFalse,
    );
  });

  test('pluginModelId is stable basename for uninstall', () {
    expect(ModelLocalCache.pluginModelId, 'ikamva_ondevice_model');
  });
}
