import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';
import 'package:ikamva_lam/llm/gemma_model_config.dart';
import 'package:ikamva_lam/llm/model_cache_checker.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake PathProvider that returns a controlled temp directory.
// ---------------------------------------------------------------------------

class _FakePathProvider
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.tempDir);

  final String tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir;

  // Provide stubs for all other required methods.
  @override
  Future<String?> getTemporaryPath() async => tempDir;

  @override
  Future<String?> getApplicationSupportPath() async => tempDir;

  @override
  Future<String?> getLibraryPath() async => null;

  @override
  Future<String?> getApplicationCachePath() async => tempDir;

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => null;

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;

  @override
  Future<String?> getDownloadsPath() async => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the model filename for [variant] (same logic as the service).
String _modelFilename(OnDeviceGemmaVariant variant) {
  return GemmaModelConfig.artifactFor(variant).filename;
}

/// Creates a non-empty file at [path] so that [hfLocalFileExistsSync] returns
/// `true` (the stub checks `File(path).existsSync()`).
void _createModelFile(String dirPath, String filename) {
  final file = File('$dirPath/$filename');
  file.createSync(recursive: true);
  file.writeAsBytesSync([0x00]); // non-zero length
}

/// Deletes the model file if it exists.
void _deleteModelFile(String dirPath, String filename) {
  final file = File('$dirPath/$filename');
  if (file.existsSync()) file.deleteSync();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    // Create a fresh temp directory for each test.
    tempDir = await Directory.systemTemp.createTemp('model_cache_checker_test_');

    // Point path_provider at our temp directory.
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    // Reset SharedPreferences to a clean state.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    // Clean up temp directory.
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Unit test 1: file absent → isCached returns false
  // ---------------------------------------------------------------------------

  test('isCached returns false when model file is absent', () async {
    // No file created — isPluginModelInstalled will return false.
    final result = await ModelCacheChecker.isCached(
      OnDeviceGemmaVariant.gemma4E2b,
    );
    expect(result, isFalse);
  });

  // ---------------------------------------------------------------------------
  // Unit test 2: file present but fingerprint mismatch → isCached returns false
  // ---------------------------------------------------------------------------

  test(
    'isCached returns false when file is present but fingerprint mismatches',
    () async {
      // Create the model file so isPluginModelInstalled returns true.
      _createModelFile(
        tempDir.path,
        _modelFilename(OnDeviceGemmaVariant.gemma4E2b),
      );

      // Do NOT call markPrepareDone — prefs are empty, so
      // shouldPrepareForFingerprint returns true (mismatch).
      final result = await ModelCacheChecker.isCached(
        OnDeviceGemmaVariant.gemma4E2b,
      );
      expect(result, isFalse);
    },
  );

  // ---------------------------------------------------------------------------
  // Unit test 3: file present and fingerprint matches → isCached returns true
  // ---------------------------------------------------------------------------

  test(
    'isCached returns true when file is present and fingerprint matches',
    () async {
      const variant = OnDeviceGemmaVariant.gemma4E2b;

      // Create the model file.
      _createModelFile(tempDir.path, _modelFilename(variant));

      // Mark prepare done with the correct fingerprint.
      final fp = ModelPrepareConfig.installFingerprint(variant);
      await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

      final result = await ModelCacheChecker.isCached(variant);
      expect(result, isTrue);
    },
  );

  // ---------------------------------------------------------------------------
  // Property 8: isCached is false when file absent
  // Feature: model-download-cache, Property 8: isCached is false when file absent
  //
  // For any variant where isPluginModelInstalled returns false,
  // ModelCacheChecker.isCached must return false regardless of prefs state.
  // Validates: Requirements 1.1, 1.5
  // ---------------------------------------------------------------------------

  group('Property 8: isCached is false when file absent', () {
    for (final variant in OnDeviceGemmaVariant.values) {
      test('variant ${variant.name} — file absent, prefs empty', () async {
        // Feature: model-download-cache, Property 8: isCached is false when file absent
        // No file created — isPluginModelInstalled returns false.
        final result = await ModelCacheChecker.isCached(variant);
        expect(
          result,
          isFalse,
          reason:
              'isCached must return false when the model file is absent '
              '(variant: ${variant.name})',
        );
      });

      test(
        'variant ${variant.name} — file absent, prefs marked done',
        () async {
          // Feature: model-download-cache, Property 8: isCached is false when file absent
          // Even if prefs say "done", the file check must fail first.
          final fp = ModelPrepareConfig.installFingerprint(variant);
          await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

          // No file created.
          final result = await ModelCacheChecker.isCached(variant);
          expect(
            result,
            isFalse,
            reason:
                'isCached must return false when the model file is absent, '
                'even if prefs are marked done (variant: ${variant.name})',
          );
        },
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Property 9: isCached is false when fingerprint mismatches
  // Feature: model-download-cache, Property 9: isCached is false when fingerprint mismatches
  //
  // For any variant where the file exists but the stored fingerprint does not
  // match, ModelCacheChecker.isCached must return false.
  // Validates: Requirements 1.4
  // ---------------------------------------------------------------------------

  group('Property 9: isCached is false when fingerprint mismatches', () {
    test(
      'file present, no prefs stored (never prepared) — all variants',
      () async {
        // Feature: model-download-cache, Property 9: isCached is false when fingerprint mismatches
        for (final variant in OnDeviceGemmaVariant.values) {
          // Reset prefs for each iteration.
          SharedPreferences.setMockInitialValues(<String, Object>{});

          _createModelFile(tempDir.path, _modelFilename(variant));

          final result = await ModelCacheChecker.isCached(variant);
          expect(
            result,
            isFalse,
            reason:
                'isCached must return false when file exists but no fingerprint '
                'is stored (variant: ${variant.name})',
          );

          // Clean up file for next iteration.
          _deleteModelFile(tempDir.path, _modelFilename(variant));
        }
      },
    );

    test(
      'file present, wrong fingerprint stored — all variants',
      () async {
        // Feature: model-download-cache, Property 9: isCached is false when fingerprint mismatches
        for (final variant in OnDeviceGemmaVariant.values) {
          // Reset prefs for each iteration.
          SharedPreferences.setMockInitialValues(<String, Object>{});

          _createModelFile(tempDir.path, _modelFilename(variant));

          // Store a fingerprint that does NOT match this variant.
          const wrongFingerprint = 'network:https://example.com/wrong-model.litertlm';
          await ModelPreparePrefs.markPrepareDone(
            installFingerprint: wrongFingerprint,
          );

          final result = await ModelCacheChecker.isCached(variant);
          expect(
            result,
            isFalse,
            reason:
                'isCached must return false when file exists but stored '
                'fingerprint does not match (variant: ${variant.name})',
          );

          // Clean up file for next iteration.
          _deleteModelFile(tempDir.path, _modelFilename(variant));
        }
      },
    );

    test(
      'file present, other variant fingerprint stored — all variants',
      () async {
        // Feature: model-download-cache, Property 9: isCached is false when fingerprint mismatches
        final variants = OnDeviceGemmaVariant.values;
        for (var i = 0; i < variants.length; i++) {
          final variant = variants[i];
          // Use the fingerprint of the OTHER variant.
          final otherVariant = variants[(i + 1) % variants.length];
          final otherFp = ModelPrepareConfig.installFingerprint(otherVariant);

          // Reset prefs for each iteration.
          SharedPreferences.setMockInitialValues(<String, Object>{});

          _createModelFile(tempDir.path, _modelFilename(variant));

          await ModelPreparePrefs.markPrepareDone(installFingerprint: otherFp);

          final result = await ModelCacheChecker.isCached(variant);
          expect(
            result,
            isFalse,
            reason:
                'isCached must return false when file exists but stored '
                'fingerprint belongs to a different variant '
                '(variant: ${variant.name}, stored: ${otherVariant.name})',
          );

          // Clean up file for next iteration.
          _deleteModelFile(tempDir.path, _modelFilename(variant));
        }
      },
    );
  });
}
