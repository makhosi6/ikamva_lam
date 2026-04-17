/// Bundled prompt pack version (TASKS Phase 7 acceptance: change files under
/// this folder only—no code edits required to swap copy).
abstract final class PromptBundle {
  static const String id = 'prompt_v3';

  static String assetPath(String fileName) => 'assets/prompts/$id/$fileName';
}
