import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/services.dart';

/// Hugging Face token for gated downloads / rate limits.
///
/// **Dart compile-time:** set **`IKAMVA_HF_TOKEN`** via `--dart-define` or
/// **`--dart-define-from-file`** (VS Code launch configs).
/// Fallback keys: **`HUGGINGFACE_TOKEN`**, **`HF_TOKEN`**.
///
/// **Android:** the app `build.gradle.kts` also reads repo-root **`.env`** and
/// bakes **`IKAMVA_HF_TOKEN`** into **`BuildConfig`**, then exposes it through a
/// method channel. [resolveEffectiveToken] uses that when compile-time values
/// are empty (e.g. `flutter build apk` without `--dart-define-from-file`).
///
/// Use [resolveEffectiveToken] / [loadToken] for **`ServiceRegistry`**, downloads,
/// and HTTP checks so Hugging Face sees a **`Bearer`** token on gated models.
abstract final class HuggingfaceAuthTokenStore {
  static const MethodChannel _androidBuildConfigChannel =
      MethodChannel('za.co.ikamvalam/hf_token');

  /// Fails fast in release when no token is available from Dart defines or Android.
  static Future<void> assertReleaseHasToken([String? alreadyResolved]) async {
    if (!kReleaseMode) return;
    final t = alreadyResolved ?? await resolveEffectiveToken();
    if (t != null && t.isNotEmpty) return;
    throw StateError(
      'Release build has no Hugging Face token. Put IKAMVA_HF_TOKEN in repo-root '
      '.env (Android embeds it from there) and/or rebuild with '
      '--dart-define-from-file pointing at that file.',
    );
  }

  /// Compile-time only (`--dart-define` / `--dart-define-from-file` at **Flutter**
  /// compile). Empty when the APK was built without passing defines, even if
  /// `.env` existed for Gradle.
  static String? resolveToken() {
    const ikamva = String.fromEnvironment('IKAMVA_HF_TOKEN');
    if (ikamva.isNotEmpty) return ikamva;
    const huggingface = String.fromEnvironment('HUGGINGFACE_TOKEN');
    if (huggingface.isNotEmpty) return huggingface;
    const hf = String.fromEnvironment('HF_TOKEN');
    if (hf.isNotEmpty) return hf;
    return null;
  }

  static Future<String?> _tokenFromAndroidBuildConfig() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final v = await _androidBuildConfigChannel
          .invokeMethod<String>('getIkamvaHfToken');
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    } on Object {
      return null;
    }
  }

  /// Token for production use: Dart defines first, then Android `BuildConfig`.
  static Future<String?> resolveEffectiveToken() async {
    final fromDart = resolveToken();
    if (fromDart != null && fromDart.isNotEmpty) {
      return fromDart;
    }
    return _tokenFromAndroidBuildConfig();
  }

  static Future<String?> loadToken() async => resolveEffectiveToken();
}
