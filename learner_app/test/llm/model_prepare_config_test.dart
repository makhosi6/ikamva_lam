import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';
import 'package:ikamva_lam/llm/gemma_model_config.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';

void main() {
  test('fileTypeForInstallSource delegates extension mapping', () {
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('https://x/model.task'),
      InstallModelFileKind.task,
    );
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('https://x/model.litertlm'),
      InstallModelFileKind.litertlm,
    );
    expect(
      ModelPrepareConfig.fileTypeForInstallSource('/tmp/model.bin'),
      InstallModelFileKind.binary,
    );
  });

  test('numeric install defaults are sane positive values', () {
    expect(ModelPrepareConfig.estimatedDownloadMb, greaterThan(0));
    expect(ModelPrepareConfig.headroomMb, greaterThan(0));
    expect(ModelPrepareConfig.minFreeDiskMb, greaterThan(0));
  });

  test('contextMaxTokensFor caps non-lowRAM Android to 512', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ModelPrepareConfig.contextMaxTokensFor(false), 512);
  });

  test('contextMaxTokensFor keeps lowRAM Android at 512', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ModelPrepareConfig.contextMaxTokensFor(true), 512);
  });

  test('contextMaxTokensFor uses compile-time env default on non-Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ModelPrepareConfig.contextMaxTokensFor(false), 1024);
  });

  test('installFingerprint distinguishes E2B HF vs E4B network', () {
    expect(
      ModelPrepareConfig.installFingerprint(OnDeviceGemmaVariant.gemma4E2b),
      startsWith('network:https://'),
    );
    expect(
      ModelPrepareConfig.installFingerprint(OnDeviceGemmaVariant.gemma4E4b),
      startsWith('network:https://'),
    );
  });
}
