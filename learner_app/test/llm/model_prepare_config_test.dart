import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/gemma4_ondevice_variant.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';

void main() {
  test('fileTypeForInstallSource delegates extension mapping', () {
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('https://x/model.task'),
      ModelFileType.task,
    );
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('https://x/model.litertlm'),
      ModelFileType.litertlm,
    );
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('/tmp/model.bin'),
      ModelFileType.binary,
    );
  });

  test('numeric install defaults are sane positive values', () {
    expect(ModelPrepareConfig.estimatedDownloadMb, greaterThan(0));
    expect(ModelPrepareConfig.headroomMb, greaterThan(0));
    expect(ModelPrepareConfig.minFreeDiskMb, greaterThan(0));
  });

  test('installFingerprint distinguishes E2B HF vs E4B network', () {
    expect(
      ModelPrepareConfig.installFingerprint(Gemma4OnDeviceVariant.e2bHuggingFace),
      startsWith('network:https://'),
    );
    expect(
      ModelPrepareConfig.installFingerprint(Gemma4OnDeviceVariant.e4bNetwork),
      startsWith('network:https://'),
    );
  });
}
