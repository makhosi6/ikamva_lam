import 'dart:convert';

import '../llm/llm_output_filters.dart';

class AiMultilingualHint {
  const AiMultilingualHint({
    required this.hintEn,
    this.hintXh,
    this.hintZu,
    this.hintAf,
  });

  final String hintEn;
  final String? hintXh;
  final String? hintZu;
  final String? hintAf;

  static AiMultilingualHint? tryParse(String raw) {
    try {
      final span = LlmOutputFilters.takeThroughFirstBalancedJson(raw);
      final decoded = jsonDecode(span);
      if (decoded is! Map<String, dynamic>) return null;
      final en = decoded['hint_en'];
      if (en is! String || en.trim().isEmpty) return null;
      return AiMultilingualHint(
        hintEn: en.trim(),
        hintXh: _optString(decoded['hint_xh']),
        hintZu: _optString(decoded['hint_zu']),
        hintAf: _optString(decoded['hint_af']),
      );
    } on Object {
      return null;
    }
  }

  static String? _optString(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}
