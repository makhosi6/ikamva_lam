import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/flutter_gemma_llm_engine.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';
import 'package:ikamva_lam/llm/gemma_model_config.dart';
import 'package:ikamva_lam/llm/llm_exceptions.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake PathProvider — returns a controlled temp directory so that
// GemmaHfModelDownloadService.getFilePath() resolves to a path we control.
// ---------------------------------------------------------------------------

class _FakePathProvider
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.tempDir);

  final String tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir;

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

/// Returns the model filename for [variant].
String _modelFilename(OnDeviceGemmaVariant variant) {
  return GemmaModelConfig.artifactFor(variant).filename;
}

/// Creates a non-empty model file so that [isPluginModelInstalled] returns true.
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

/// Creates a [FlutterGemmaLlmEngine] for [variant] with lifecycle hooks
/// that record emitted phases into [phases].
FlutterGemmaLlmEngine _makeEngine(
  OnDeviceGemmaVariant variant,
  List<String> phases,
) {
  final settings = SettingsStore();
  // Directly set the variant field via the public getter — SettingsStore
  // exposes gemma4OnDeviceVariant as a getter backed by a private field.
  // We use a subclass-free approach: load() defaults to gemma4E2b,
  // so for e4b we need to set it. We use setOnDeviceGemmaVariant which
  // writes to prefs — but since we only need the in-memory value for the
  // engine constructor, we call the sync setter via a workaround.
  //
  // SettingsStore does not expose a synchronous setter, so we create a
  // minimal settings object and rely on the default (gemma4E2b) for
  // that variant, or use a helper that sets the field before the engine
  // is constructed.
  final hooks = LlmInstallUiHooks()
    ..onLifecycle = (phase, message, percent) {
      phases.add(phase);
    };
  return FlutterGemmaLlmEngine(settings: settings, installUiHooks: hooks);
}

/// Creates a [SettingsStore] with [variant] set synchronously by loading
/// from mock prefs that contain the variant name.
Future<SettingsStore> _settingsForVariant(
  OnDeviceGemmaVariant variant,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'gemma4_ondevice_variant': variant.name,
  });
  final settings = SettingsStore();
  await settings.load();
  return settings;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'flutter_gemma_cache_gate_test_',
    );
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Existing test: non-mobile host throws LlmUnavailableException
  //
  // This verifies the existing behaviour is preserved after the cache gate
  // was added to _ensureLoadedBody.
  // ---------------------------------------------------------------------------

  test(
    'ensureLoaded throws LlmUnavailableException on non-mobile host',
    () async {
      if (shouldUseFlutterGemmaEngine) {
        // Running on a real mobile device — skip this non-mobile assertion.
        return;
      }

      final settings = SettingsStore();
      await settings.load();
      final hooks = LlmInstallUiHooks();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: hooks,
      );

      await expectLater(
        engine.ensureLoaded(),
        throwsA(isA<LlmUnavailableException>()),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Property 1: Cache hit skips download
  // Feature: model-download-cache, Property 1: Cache hit skips download
  //
  // For any OnDeviceGemmaVariant, if ModelCacheChecker.isCached(variant)
  // returns true, then calling _ensureLoadedBody must not invoke
  // _installFromConfiguredSource (no download is triggered).
  //
  // Observable proxy: when cached, the engine emits lifecycle phase 'open'
  // with message 'Model found in storage — opening…' and does NOT emit the
  // install-path message 'Looking for on-device Gemma weights…'.
  //
  // Validates: Requirements 1.2, 2.1
  // ---------------------------------------------------------------------------

  group('Property 1: Cache hit skips download', () {
    for (final variant in OnDeviceGemmaVariant.values) {
      test('variant ${variant.name} — cache hit emits open, not install', () async {
        // Feature: model-download-cache, Property 1: Cache hit skips download
        if (!shouldUseFlutterGemmaEngine) {
          // The platform guard fires before the cache gate on non-mobile hosts.
          // This property is verified on mobile CI where the full path runs.
          // On non-mobile, we verify the cache gate logic via ModelCacheChecker
          // unit tests (task 1.1) and the lifecycle-event contract below.
          markTestSkipped(
            'Property 1 requires a mobile host to exercise the cache gate path. '
            'Verified via ModelCacheChecker unit tests on non-mobile.',
          );
          return;
        }

        // Arrange: create the model file and mark prefs done so isCached → true.
        _createModelFile(tempDir.path, _modelFilename(variant));
        final fp = ModelPrepareConfig.installFingerprint(variant);
        await ModelPreparePrefs.markPrepareDone(installFingerprint: fp);

        final settings = await _settingsForVariant(variant);
        final phases = <String>[];
        final messages = <String>[];
        final hooks = LlmInstallUiHooks()
          ..onLifecycle = (phase, message, percent) {
            phases.add(phase);
            messages.add(message);
          };
        final engine = FlutterGemmaLlmEngine(
          settings: settings,
          installUiHooks: hooks,
        );

        // Act: ensureLoaded will fail at _openActiveModel (no native channel),
        // but we can observe the lifecycle events emitted before that failure.
        try {
          await engine.ensureLoaded();
        } on Object {
          // Expected: native open will fail in test environment.
        }

        // Assert: the cache-hit branch emits 'open' with the storage message.
        expect(
          messages,
          contains('Model found in storage — opening…'),
          reason:
              'Cache hit must emit the storage-open message '
              '(variant: ${variant.name})',
        );

        // Assert: the install-path message must NOT appear.
        expect(
          messages.any((m) => m.contains('Looking for on-device Gemma weights')),
          isFalse,
          reason:
              'Cache hit must not trigger the install path '
              '(variant: ${variant.name})',
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Property 2: Cache miss triggers install
  // Feature: model-download-cache, Property 2: Cache miss triggers install
  //
  // For any OnDeviceGemmaVariant, if ModelCacheChecker.isCached(variant)
  // returns false, then _ensureLoadedBody must call _installFromConfiguredSource
  // before attempting to open the model.
  //
  // Observable proxy: when not cached, the engine emits the install-path
  // lifecycle message 'Looking for on-device Gemma weights…' and does NOT
  // emit 'Model found in storage — opening…'.
  //
  // Validates: Requirements 1.3, 2.1
  // ---------------------------------------------------------------------------

  group('Property 2: Cache miss triggers install', () {
    for (final variant in OnDeviceGemmaVariant.values) {
      test(
        'variant ${variant.name} — cache miss emits install path, not storage-open',
        () async {
          // Feature: model-download-cache, Property 2: Cache miss triggers install
          if (!shouldUseFlutterGemmaEngine) {
            markTestSkipped(
              'Property 2 requires a mobile host to exercise the cache gate path. '
              'Verified via ModelCacheChecker unit tests on non-mobile.',
            );
            return;
          }

          // Arrange: no model file, no prefs → isCached returns false.
          _deleteModelFile(tempDir.path, _modelFilename(variant));
          SharedPreferences.setMockInitialValues(<String, Object>{});

          final settings = await _settingsForVariant(variant);
          final phases = <String>[];
          final messages = <String>[];
          final hooks = LlmInstallUiHooks()
            ..onLifecycle = (phase, message, percent) {
              phases.add(phase);
              messages.add(message);
            };
          final engine = FlutterGemmaLlmEngine(
            settings: settings,
            installUiHooks: hooks,
          );

          // Act: ensureLoaded will fail (no network / native channel in tests),
          // but we observe the lifecycle events emitted before the failure.
          try {
            await engine.ensureLoaded();
          } on Object {
            // Expected: download or native open will fail in test environment.
          }

          // Assert: the cache-miss branch emits the install-path message.
          expect(
            messages.any((m) => m.contains('Looking for on-device Gemma weights')),
            isTrue,
            reason:
                'Cache miss must trigger the install path '
                '(variant: ${variant.name})',
          );

          // Assert: the storage-open message must NOT appear.
          expect(
            messages,
            isNot(contains('Model found in storage — opening…')),
            reason:
                'Cache miss must not emit the storage-open message '
                '(variant: ${variant.name})',
          );
        },
      );
    }

    test(
      'cache miss with fingerprint mismatch triggers install — all variants',
      () async {
        // Feature: model-download-cache, Property 2: Cache miss triggers install
        if (!shouldUseFlutterGemmaEngine) {
          markTestSkipped(
            'Property 2 requires a mobile host to exercise the cache gate path.',
          );
          return;
        }

        for (final variant in OnDeviceGemmaVariant.values) {
          // Reset state for each iteration.
          SharedPreferences.setMockInitialValues(<String, Object>{});

          // File exists but fingerprint is wrong → isCached returns false.
          _createModelFile(tempDir.path, _modelFilename(variant));
          const wrongFp = 'network:https://example.com/wrong-model.litertlm';
          await ModelPreparePrefs.markPrepareDone(installFingerprint: wrongFp);

          final settings = await _settingsForVariant(variant);
          final messages = <String>[];
          final hooks = LlmInstallUiHooks()
            ..onLifecycle = (phase, message, percent) {
              messages.add(message);
            };
          final engine = FlutterGemmaLlmEngine(
            settings: settings,
            installUiHooks: hooks,
          );

          try {
            await engine.ensureLoaded();
          } on Object {
            // Expected failure in test environment.
          }

          expect(
            messages.any((m) => m.contains('Looking for on-device Gemma weights')),
            isTrue,
            reason:
                'Fingerprint mismatch must trigger the install path '
                '(variant: ${variant.name})',
          );

          expect(
            messages,
            isNot(contains('Model found in storage — opening…')),
            reason:
                'Fingerprint mismatch must not emit the storage-open message '
                '(variant: ${variant.name})',
          );

          // Clean up for next iteration.
          _deleteModelFile(tempDir.path, _modelFilename(variant));
        }
      },
    );
  });
}
