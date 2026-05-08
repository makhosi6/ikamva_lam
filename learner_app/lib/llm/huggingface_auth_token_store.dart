/// Hugging Face token for gated downloads / rate limits.
///
/// Set **`IKAMVA_HF_TOKEN`** in repo-root **`.env`** and run or build with
/// **`--dart-define-from-file`** pointing at that file (VS Code launch configs
/// in this repo already do this).
/// Fallback compile-time keys: **`HUGGINGFACE_TOKEN`**, **`HF_TOKEN`**.
abstract final class HuggingfaceAuthTokenStore {
  /// Resolved at compile/build time from `--dart-define` / `--dart-define-from-file`.
  static String? resolveToken() {
    const ikamva = String.fromEnvironment('IKAMVA_HF_TOKEN');
    if (ikamva.isNotEmpty) return ikamva;
    const huggingface = String.fromEnvironment('HUGGINGFACE_TOKEN');
    if (huggingface.isNotEmpty) return huggingface;
    const hf = String.fromEnvironment('HF_TOKEN');
    if (hf.isNotEmpty) return hf;
    return null;
  }

  static Future<String?> loadToken() async => resolveToken();
}
