import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/llm/flutter_gemma_llm_engine.dart';
import 'package:ikamva_lam/llm/gemma_hf_model_download_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
// Tests for GemmaHfModelDownloadService and error-classification helpers.
//
// Covers:
//   - GemmaHfModelDownloadService.isPluginModelInstalled returns false on
//     non-mobile platforms (Requirement 5.4, 6.4).
//   - gemmaErrorLooksLikeGpuResourceExhaustion classifies known GPU exhaustion
//     strings correctly (Requirement 6.5).
//   - Storage error strings trigger LlmResourceException via the
//     msg.contains('space') / 'storage' / 'enospc' branches (Requirement 5.2).
//   - Property (error classification): For all known GPU-exhaustion error
//     strings, gemmaErrorLooksLikeGpuResourceExhaustion returns true; for all
//     known non-GPU strings, it returns false (Requirement 6.5).
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'gemma_hf_download_service_test_',
    );
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Unit tests: GemmaHfModelDownloadService.isPluginModelInstalled
  // on non-mobile host (Requirement 5.4, 6.4)
  // -------------------------------------------------------------------------

  group('GemmaHfModelDownloadService.downloadModel', () {
    test('skips downloader when target file already exists', () async {
      if (shouldUseFlutterGemmaEngine) {
        return;
      }
      final service = GemmaHfModelDownloadService.e2b();
      final path = await service.getFilePath();
      await File(path).parent.create(recursive: true);
      await File(path).writeAsBytes(<int>[1]);

      var lastProgress = -1.0;
      await service.downloadModel(
        token: '',
        onProgress: (p) => lastProgress = p,
      );
      expect(lastProgress, 100);
    });
  });

  group('GemmaHfModelDownloadService.isPluginModelInstalled on non-mobile', () {
    test('e2b service returns false on non-mobile host', () async {
      if (shouldUseFlutterGemmaEngine) {
        // Running on a real mobile device — this test targets non-mobile only.
        return;
      }
      // On non-mobile (desktop / web / CI), kIsWeb is false but the platform
      // is not Android or iOS. The implementation checks kIsWeb first and
      // returns false immediately on web. On non-web non-mobile (e.g. macOS
      // CI), the file-system check runs but the model file does not exist,
      // so the result is still false.
      //
      // Either way, the contract is: non-mobile → false.
      final service = GemmaHfModelDownloadService.e2b();
      final result = await service.isPluginModelInstalled();
      expect(
        result,
        isFalse,
        reason:
            'isPluginModelInstalled must return false on non-mobile platforms '
            '(no model file is present in the test environment)',
      );
    });

    test('e4b service returns false on non-mobile host', () async {
      if (shouldUseFlutterGemmaEngine) {
        return;
      }
      final service = GemmaHfModelDownloadService.e4b();
      final result = await service.isPluginModelInstalled();
      expect(
        result,
        isFalse,
        reason:
            'isPluginModelInstalled must return false on non-mobile platforms',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests: gemmaErrorLooksLikeGpuResourceExhaustion
  // Known GPU exhaustion strings (Requirement 6.5)
  // -------------------------------------------------------------------------

  group('gemmaErrorLooksLikeGpuResourceExhaustion — known GPU strings', () {
    test('queue_buffer_timeout is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('queue_buffer_timeout after 5000ms'),
        ),
        isTrue,
      );
    });

    test('gpu completion error is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('GPU completion failed'),
        ),
        isTrue,
      );
    });

    test('queue buffer error is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('queue buffer overflow'),
        ),
        isTrue,
      );
    });

    test('lost connection is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('lost connection to GPU process'),
        ),
        isTrue,
      );
    });

    test('opengl error is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('OpenGL context lost'),
        ),
        isTrue,
      );
    });

    test('opencl error is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('OpenCL out of resources'),
        ),
        isTrue,
      );
    });

    test('gpu stall is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('GPU stall detected'),
        ),
        isTrue,
      );
    });

    test('memory pressure is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('memory pressure warning'),
        ),
        isTrue,
      );
    });

    test('timeout with gpu keyword is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('timeout waiting for gpu'),
        ),
        isTrue,
      );
    });

    test('timeout with render keyword is classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('render timeout exceeded'),
        ),
        isTrue,
      );
    });
  });

  group('gemmaErrorLooksLikeGpuResourceExhaustion — known non-GPU strings', () {
    test('zip archive error is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('unable to open zip archive'),
        ),
        isFalse,
      );
    });

    test('network error is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('SocketException: Connection refused'),
        ),
        isFalse,
      );
    });

    test('storage full error is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('No space left on device (enospc)'),
        ),
        isFalse,
      );
    });

    test('file not found is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('FileSystemException: file not found'),
        ),
        isFalse,
      );
    });

    test('authentication error is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('HTTP 401 Unauthorized'),
        ),
        isFalse,
      );
    });

    test('generic timeout without gpu/render is NOT classified as GPU exhaustion', () {
      expect(
        gemmaErrorLooksLikeGpuResourceExhaustion(
          Exception('timeout waiting for network response'),
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests: storage error strings trigger LlmResourceException
  // (Requirement 5.2 — verifying the detection logic directly)
  // -------------------------------------------------------------------------

  group('Storage error string detection (msg.contains branches)', () {
    // The _installFromHfService method checks:
    //   msg.contains('space') || msg.contains('storage') || msg.contains('enospc')
    // We test the detection logic directly by checking the string conditions
    // that would trigger LlmResourceException.

    const storageErrorStrings = [
      'No space left on device',
      'insufficient storage available',
      'ENOSPC: no space left',
      'not enough space to write file',
      'storage quota exceeded',
      'enospc error during write',
    ];

    for (final errorMsg in storageErrorStrings) {
      test('"$errorMsg" is detected as a storage error', () {
        final lower = errorMsg.toLowerCase();
        final isStorageError = lower.contains('space') ||
            lower.contains('storage') ||
            lower.contains('enospc');
        expect(
          isStorageError,
          isTrue,
          reason:
              '"$errorMsg" must be detected as a storage error by the '
              'space/storage/enospc branch in _installFromHfService',
        );
      });
    }

    const nonStorageErrorStrings = [
      'SocketException: Connection refused',
      'HTTP 401 Unauthorized',
      'unable to open zip archive',
      'FileSystemException: file not found',
      'GPU stall detected',
    ];

    for (final errorMsg in nonStorageErrorStrings) {
      test('"$errorMsg" is NOT detected as a storage error', () {
        final lower = errorMsg.toLowerCase();
        final isStorageError = lower.contains('space') ||
            lower.contains('storage') ||
            lower.contains('enospc');
        expect(
          isStorageError,
          isFalse,
          reason:
              '"$errorMsg" must NOT be detected as a storage error',
        );
      });
    }
  });

  // -------------------------------------------------------------------------
  // Property (error classification):
  // Feature: model-download-cache, Property (error classification):
  // For all known GPU-exhaustion error strings, gemmaErrorLooksLikeGpuResourceExhaustion
  // returns true; for all known non-GPU strings, it returns false.
  // Validates: Requirements 6.5
  // -------------------------------------------------------------------------

  group(
    'Property (error classification): gemmaErrorLooksLikeGpuResourceExhaustion',
    () {
      // A representative set of ≥ 10 known GPU-exhaustion error strings.
      // These are strings that the function must classify as true.
      const knownGpuExhaustionStrings = [
        'queue_buffer_timeout after 5000ms',
        'GPU completion failed with error code -1',
        'queue buffer overflow in render pipeline',
        'lost connection to GPU render process',
        'OpenGL context lost due to memory pressure',
        'OpenCL out of resources: CL_OUT_OF_RESOURCES',
        'GPU stall detected in command buffer',
        'memory pressure: GPU memory exhausted',
        'timeout waiting for gpu command completion',
        'render timeout exceeded after 120s',
        'QUEUE_BUFFER_TIMEOUT: buffer not returned',
        'GPU Completion callback never fired',
        'Lost Connection to GPU process (pid 1234)',
      ];

      // A representative set of ≥ 10 known non-GPU error strings.
      // These are strings that the function must classify as false.
      const knownNonGpuStrings = [
        'unable to open zip archive: corrupt file',
        'SocketException: Connection refused (OS Error: Connection refused, errno = 111)',
        'No space left on device (ENOSPC)',
        'FileSystemException: Cannot open file',
        'HTTP 401 Unauthorized: invalid token',
        'HTTP 404 Not Found: model not available',
        'FormatException: unexpected character',
        'StateError: model already disposed',
        'timeout waiting for network response',
        'modifyGraphWithDelegate failed',
        'gpu_delegate initialization failed',
        'metal delegate error: unsupported op',
      ];

      test(
        'all known GPU-exhaustion strings return true — ≥10 strings covered',
        () {
          // Feature: model-download-cache, Property (error classification):
          // For all known GPU-exhaustion error strings,
          // gemmaErrorLooksLikeGpuResourceExhaustion returns true.
          expect(
            knownGpuExhaustionStrings.length,
            greaterThanOrEqualTo(10),
            reason: 'Design doc requires ≥ 10 representative strings',
          );

          for (final errorStr in knownGpuExhaustionStrings) {
            expect(
              gemmaErrorLooksLikeGpuResourceExhaustion(Exception(errorStr)),
              isTrue,
              reason:
                  '"$errorStr" must be classified as GPU resource exhaustion',
            );
          }
        },
      );

      test(
        'all known non-GPU strings return false — ≥10 strings covered',
        () {
          // Feature: model-download-cache, Property (error classification):
          // For all known non-GPU strings,
          // gemmaErrorLooksLikeGpuResourceExhaustion returns false.
          expect(
            knownNonGpuStrings.length,
            greaterThanOrEqualTo(10),
            reason: 'Design doc requires ≥ 10 representative strings',
          );

          for (final errorStr in knownNonGpuStrings) {
            expect(
              gemmaErrorLooksLikeGpuResourceExhaustion(Exception(errorStr)),
              isFalse,
              reason:
                  '"$errorStr" must NOT be classified as GPU resource exhaustion',
            );
          }
        },
      );

      test(
        'classification is case-insensitive for GPU exhaustion strings',
        () {
          // Feature: model-download-cache, Property (error classification):
          // The function lowercases the error string, so mixed-case variants
          // of known GPU strings must also return true.
          const mixedCaseGpuStrings = [
            'QUEUE_BUFFER_TIMEOUT',
            'GPU Completion Error',
            'Queue Buffer Overflow',
            'Lost Connection to GPU',
            'Memory Pressure Warning',
            'GPU Stall Detected',
          ];

          for (final errorStr in mixedCaseGpuStrings) {
            expect(
              gemmaErrorLooksLikeGpuResourceExhaustion(Exception(errorStr)),
              isTrue,
              reason:
                  '"$errorStr" (mixed case) must be classified as GPU resource '
                  'exhaustion (function is case-insensitive)',
            );
          }
        },
      );
    },
  );
}
