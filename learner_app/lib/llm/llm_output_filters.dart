/// Post-process model stdout for JSON-only prompts (TASKS §6.6).
abstract final class LlmOutputFilters {
  /// Returns the substring from the first `{` through the first balanced `}`
  /// brace depth, or [raw] if no sensible JSON span is found.
  static String takeThroughFirstBalancedJson(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return raw.trim();
    var depth = 0;
    for (var i = start; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x7B) {
        depth++;
      } else if (c == 0x7D) {
        depth--;
        if (depth == 0) {
          return raw.substring(start, i + 1).trim();
        }
      }
    }
    return raw.substring(start).trim();
  }
}
