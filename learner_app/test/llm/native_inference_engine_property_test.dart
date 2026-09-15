import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/flutter_gemma_llm_engine.dart';
import 'package:ikamva_lam/llm/on_device_gemma_variant.dart';
import 'package:ikamva_lam/llm/gemma_inference_defaults.dart';
import 'package:ikamva_lam/llm/gemma_model_config.dart';
import 'package:ikamva_lam/llm/llm_generate_request.dart';
import 'package:ikamva_lam/llm/llm_limits.dart';
import 'package:ikamva_lam/llm/model_prepare_config.dart';
import 'package:ikamva_lam/llm/model_prepare_prefs.dart';
import 'package:ikamva_lam/llm/native_llm_platform.dart';
import 'package:ikamva_lam/state/settings_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [Platform.script] is unreliable under `flutter test`; locate the package
/// directory that contains `pubspec.yaml` for `ikamva_lam`.
Directory _ikamvaLamPackageRoot() {
  final seeds = <Directory>{
    Directory.current,
    Directory(p.join(Directory.current.path, 'learner_app')),
  };
  for (final start in seeds) {
    var dir = start;
    for (var i = 0; i < 16; i++) {
      final pub = File(p.join(dir.path, 'pubspec.yaml'));
      if (pub.existsSync()) {
        final text = pub.readAsStringSync();
        if (text.contains('name: ikamva_lam')) return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError(
    'Could not locate ikamva_lam pubspec.yaml from ${Directory.current.path}',
  );
}

String _libSourcePath(String relativeToLib) =>
    p.join(_ikamvaLamPackageRoot().path, 'lib', relativeToLib);

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

void _createModelFile(String dirPath, OnDeviceGemmaVariant variant) {
  final name = GemmaModelConfig.artifactFor(variant).filename;
  final f = File('$dirPath/$name');
  f.createSync(recursive: true);
  f.writeAsBytesSync([1, 2, 3]);
}

Future<SettingsStore> _settingsForVariant(OnDeviceGemmaVariant variant) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'gemma4_ondevice_variant': variant.name,
  });
  final s = SettingsStore();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 15: shouldUseFlutterGemmaEngine predicate', () {
    test('all combinations of web / android / ios flags', () {
      for (final web in [false, true]) {
        for (final android in [false, true]) {
          for (final ios in [false, true]) {
            final got = computeShouldUseFlutterGemmaEngine(
              isWeb: web,
              isAndroid: android,
              isIos: ios,
            );
            if (web) {
              expect(got, isFalse);
            } else {
              expect(got, android || ios);
            }
          }
        }
      }
    });
  });

  group('Property 16: Dart argument map schema', () {
    test('representative LlmGenerateRequest values', () {
      final settings = SettingsStore();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );
      final requests = <LlmGenerateRequest>[
        const LlmGenerateRequest(
          prompt: ModelBoundPrompt('a'),
          maxTokens: 10,
        ),
        const LlmGenerateRequest(
          prompt: ModelBoundPrompt('hello world'),
          maxTokens: 1,
          stopSequences: ['</s>'],
        ),
        LlmGenerateRequest(
          prompt: ModelBoundPrompt('x' * 200),
          maxTokens: 512,
        ),
      ];
      for (final r in requests) {
        final m = engine.channelArgsForTest(r);
        expect(m.keys.toSet(), const {
          'prompt',
          'temperature',
          'randomSeed',
          'topK',
          'topP',
          'enableThinking',
          'maxNewTokens',
        });
        expect(m['prompt'], isA<String>());
        expect(m['temperature'], isA<double>());
        expect(m['randomSeed'], isA<int>());
        expect(m['topK'], isA<int>());
        expect(m['topP'], isA<double>());
        expect(m['enableThinking'], isA<bool>());
        expect(m['maxNewTokens'], isA<int>());
        expect(m['temperature'], GemmaInferenceDefaults.temperature);
        expect(
          m['maxNewTokens'],
          LlmLimits.clampMaxNewTokens(
            r.maxTokens ?? LlmLimits.defaultMaxNewTokens,
          ),
        );
      }
    });
  });

  group('Property 13: stop sequence truncation', () {
    test('truncates at earliest occurrence among stops', () {
      final settings = SettingsStore();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );
      expect(
        engine.applyStopSequencesForTest('hello bar foo', ['foo', 'bar']),
        'hello ',
      );
      expect(engine.applyStopSequencesForTest('abc', []), 'abc');
      expect(engine.applyStopSequencesForTest('abc', ['']), 'abc');
    });

    test('deterministic edge cases', () {
      final settings = SettingsStore();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );
      expect(
        engine.applyStopSequencesForTest('aaSTOP1bbSTOP2cc', ['STOP2', 'STOP1']),
        'aa',
      );
    });

    test('100 generated strings — truncation never retains text at or after first stop',
        () {
      final settings = SettingsStore();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );
      for (var i = 0; i < 100; i++) {
        final marker = 'S${i}TOP';
        final text = '${'u'.padLeft(5, 'u')}$marker${'v'.padLeft(5, 'v')}';
        final out = engine.applyStopSequencesForTest(text, [marker, 'vv']);
        expect(out, 'uuuuu');
        expect(out.contains(marker), isFalse);
      }
    });
  });

  group('Property 14: error classifiers', () {
    const metalHits = <String>[
      'ModifyGraphWithDelegate failed',
      'error Gpu_delegate',
      'LLM_LITERT_METAL',
      'litert_metal_executor',
      'TfLiteGpuDelegate',
      'metal delegate error',
    ];
    const exhaustionHits = <String>[
      'queue_buffer_timeout',
      'GPU completion stalled',
      'queue buffer is full',
      'lost connection to device',
      'OpenGL error',
      'OpenCL out of resources',
      'gpu stall detected',
      'memory pressure warning',
      'timeout on gpu',
      'timeout during render',
    ];
    const zipHits = <String>[
      'zip archive is corrupt',
      'unable to open zip archive',
      'unable to open the zip file',
    ];

    test('known strings per category', () {
      for (final s in metalHits) {
        expect(gemmaErrorLooksLikeGpuMetalDelegateFailure(s), isTrue);
        expect(gemmaErrorLooksLikeInvalidTaskArchive(Exception(s)), isFalse);
      }
      for (final s in exhaustionHits) {
        expect(gemmaErrorLooksLikeGpuResourceExhaustion(s), isTrue);
      }
      for (final s in zipHits) {
        expect(gemmaErrorLooksLikeInvalidTaskArchive(Exception(s)), isTrue);
      }
    });

    test('100 iterations mixed-case noise', () {
      for (var i = 0; i < 100; i++) {
        final noise = List<String>.generate(
          12,
          (j) => String.fromCharCode(65 + (i + j) % 26),
        ).join();
        for (final base in metalHits) {
          final s = '${base.toUpperCase()} $noise';
          expect(gemmaErrorLooksLikeGpuMetalDelegateFailure(s), isTrue);
        }
        for (final base in exhaustionHits) {
          final s = '$noise ${base.toLowerCase()}';
          expect(gemmaErrorLooksLikeGpuResourceExhaustion(s), isTrue);
        }
        for (final base in zipHits) {
          final s = '$noise $base';
          expect(gemmaErrorLooksLikeInvalidTaskArchive(Exception(s)), isTrue);
        }
        expect(
          gemmaErrorLooksLikeGpuMetalDelegateFailure('clean $noise message'),
          isFalse,
        );
      }
    });
  });

  group('Property 8: StateError after dispose', () {
    test('generate and stream', () async {
      final settings = SettingsStore();
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );
      engine.dispose();
      final req = LlmGenerateRequest(
        prompt: const ModelBoundPrompt('hi'),
        maxTokens: 4,
      );
      await expectLater(engine.generate(req), throwsStateError);
      final stream = engine.generateChunkStream(req);
      await expectLater(stream.first, throwsStateError);
    });
  });

  group('Native stream event mapping', () {
    test('String, token map, error map', () {
      expect(mapNativeLlmStreamEvent('tok'), 'tok');
      expect(mapNativeLlmStreamEvent(<String, Object?>{'token': 'x'}), 'x');
      expect(
        () => mapNativeLlmStreamEvent(<String, Object?>{'error': 'boom'}),
        throwsA(isA<PlatformException>()),
      );
      expect(mapNativeLlmStreamEvent(<String, Object?>{}), '');
    });
  });

  group('Property 12: ensureLoaded deduplication (mobile)', () {
    const method = MethodChannel('za.co.ikamvalam/native_llm');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, null);
    });

    test('concurrent ensureLoaded invokes loadModel once', () async {
      if (!shouldUseFlutterGemmaEngine) {
        return;
      }
      final tempDir = Directory.systemTemp.createTempSync('llm_dedup_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final variant = OnDeviceGemmaVariant.gemma4E2b;
      _createModelFile(tempDir.path, variant);
      await ModelPreparePrefs.markPrepareDone(
        installFingerprint: ModelPrepareConfig.installFingerprint(variant),
      );

      var loadCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, (call) async {
            switch (call.method) {
              case 'loadModel':
                loadCount++;
                await Future<void>.delayed(const Duration(milliseconds: 40));
                return null;
              case 'closeModel':
                return null;
              default:
                return null;
            }
          });

      final settings = await _settingsForVariant(variant);
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );

      await Future.wait([
        engine.ensureLoaded(),
        engine.ensureLoaded(),
        engine.ensureLoaded(),
      ]);

      expect(loadCount, 1);
      engine.dispose();
    });
  });

  group('Property 10: GPU failure → CPU retry (text-only config)', () {
    const method = MethodChannel('za.co.ikamvalam/native_llm');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, null);
    });

    test(
      'mobile mock: first GPU load fails, second attempt uses CPU when not multimodal-locked',
      () async {
      if (!shouldUseFlutterGemmaEngine) {
        return;
      }
      if (GemmaModelConfig.activeModelSupportImage ||
          GemmaModelConfig.activeModelSupportAudio) {
        return;
      }
      // Android defaults to CPU for text-only; GPU→CPU fallback is not used.
      if (Platform.isAndroid) {
        const optIn = int.fromEnvironment('IKAMVA_ANDROID_GPU', defaultValue: 0);
        const optStr =
            String.fromEnvironment('IKAMVA_PREFER_ANDROID_GPU', defaultValue: '');
        final gpuOptIn = optIn != 0 ||
            optStr == 'true' ||
            optStr == 'TRUE';
        if (!gpuOptIn) return;
      }
      final tempDir = Directory.systemTemp.createTempSync('llm_gpu_fallback_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final variant = OnDeviceGemmaVariant.gemma4E2b;
      _createModelFile(tempDir.path, variant);
      await ModelPreparePrefs.markPrepareDone(
        installFingerprint: ModelPrepareConfig.installFingerprint(variant),
      );

      final preferFlags = <bool>[];
      var loadAttempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, (call) async {
            if (call.method == 'loadModel') {
              final m = call.arguments! as Map<dynamic, dynamic>;
              preferFlags.add(m['preferGpu'] as bool);
              loadAttempts++;
              if (loadAttempts == 1) {
                throw PlatformException(
                  code: 'load_failed',
                  message: 'gpu_delegate',
                );
              }
              return null;
            }
            return null;
          });

      final settings = await _settingsForVariant(variant);
      final engine = FlutterGemmaLlmEngine(
        settings: settings,
        installUiHooks: LlmInstallUiHooks(),
      );

      await engine.ensureLoaded();

      expect(preferFlags, contains(true));
      expect(preferFlags, contains(false));
      engine.dispose();
    });
  });

  group('GemmaHfModelDownloadService web guard (source)', () {
    test('isPluginModelInstalled returns false when kIsWeb', () {
      final src = File(_libSourcePath('llm/gemma_hf_model_download_service.dart'))
          .readAsStringSync();
      expect(src.contains('if (kIsWeb) return false'), isTrue);
    });
  });

  group('FlutterGemmaLlmEngine GPU fallback path (source)', () {
    test(
        'Properties 5.3, 9, 11: CPU fallback, multimodal guard, Android CPU default',
        () {
      final src = File(_libSourcePath('llm/flutter_gemma_llm_engine.dart'))
          .readAsStringSync();
      expect(src.contains("await _nativeOpen(preferGpu: false)"), isTrue);
      expect(src.contains('gpu_fallback_to_cpu'), isTrue);
      expect(src.contains('_multimodalRequiresGpu'), isTrue);
      expect(src.contains('GPU backend failed'), isTrue);
      expect(src.contains('_preferGpu && !_multimodalRequiresGpu'), isTrue);
      expect(src.contains('_textOnlyPreferGpuOnHost'), isTrue);
      expect(src.contains('IKAMVA_ANDROID_GPU'), isTrue);
    });
  });
}
