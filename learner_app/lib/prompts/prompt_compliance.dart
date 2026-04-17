import 'dart:convert';

import '../llm/llm_output_filters.dart';

/// Detects model escape hatch from TASKS §7.2 (`{}` compliance refusal).
///
/// Callers may treat [isEmptyComplianceObject] as "retry with simpler prompt"
/// (wired in Phase 8 generation pipeline).
bool isEmptyComplianceObject(String rawModelOutput) {
  final trimmed = rawModelOutput.trim();
  if (trimmed.isEmpty) return true;
  try {
    final span = LlmOutputFilters.takeThroughFirstBalancedJson(trimmed);
    final decoded = jsonDecode(span);
    if (decoded is Map && decoded.isEmpty) return true;
  } on Object {
    // ignore
  }
  return false;
}
