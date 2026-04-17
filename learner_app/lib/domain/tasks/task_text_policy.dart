/// Word counting for policy checks (TASKS §3.5). Splits on whitespace.
int countWords(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
}

bool _nonEmpty(String s) => s.trim().isNotEmpty;

/// Case-fold for duplicate detection (English-centric; good enough for MVP).
String foldKey(String s) => s.trim().toLowerCase();

/// Case-insensitive equality for short English tokens / phrases.
bool stringsEqualIgnoreCase(String a, String b) => foldKey(a) == foldKey(b);

/// Returns duplicate values (folded) if any appear more than once.
List<String> duplicateFoldedStrings(Iterable<String> items) {
  final seen = <String>{};
  final dups = <String>{};
  for (final s in items) {
    if (!_nonEmpty(s)) continue;
    final f = foldKey(s);
    if (!seen.add(f)) dups.add(f);
  }
  return dups.toList();
}
