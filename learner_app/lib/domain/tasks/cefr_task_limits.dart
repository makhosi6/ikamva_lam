/// Per-level caps for generated / cached task text (TASKS §3.5, spec §4.3).
///
/// Unknown or blank [levelCode] falls back to **B1**-style limits (conservative
/// for mixed classrooms).
abstract final class CefrTaskLimits {
  /// Normalises quest / payload level strings (e.g. `a1`, ` A1 ` → `A1`).
  static String normalizeLevel(String? levelCode) {
    if (levelCode == null) return '';
    return levelCode.trim().toUpperCase();
  }

  /// Max words allowed in a single cloze **sentence** stem (TASKS: &lt;10 for A1).
  static int maxWordsClozeSentence(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 10;
      case 'A2':
        return 12;
      case 'B1':
        return 15;
      case 'B2':
        return 20;
      case 'C1':
      case 'C2':
        return 28;
      default:
        return 15;
    }
  }

  /// Max words per **reorder token** (short phrase).
  static int maxWordsReorderToken(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 4;
      case 'A2':
        return 5;
      case 'B1':
      case 'B2':
        return 6;
      default:
        return 5;
    }
  }

  /// Max words for dialogue **context** or **question** blocks.
  static int maxWordsDialogueBlock(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 25;
      case 'A2':
        return 35;
      case 'B1':
      case 'B2':
        return 50;
      default:
        return 35;
    }
  }

  /// Max words per **match** column label.
  static int maxWordsMatchLabel(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 5;
      case 'A2':
        return 6;
      default:
        return 8;
    }
  }

  /// Read-aloud **display** line (single utterance).
  static int maxWordsReadAloudLine(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 12;
      case 'A2':
        return 16;
      default:
        return 22;
    }
  }

  /// Prosody / pronunciation MCQ **question** line.
  static int maxWordsProsodyQuestion(String? levelCode) {
    switch (normalizeLevel(levelCode)) {
      case 'A1':
        return 18;
      case 'A2':
        return 24;
      default:
        return 32;
    }
  }
}
