/// Replaces `{{KEY}}` placeholders in a template (keys are UPPER_SNAKE in assets).
String applyPromptSlots(String template, Map<String, String> slots) {
  var out = template;
  for (final e in slots.entries) {
    out = out.replaceAll('{{${e.key}}}', e.value);
  }
  return out;
}
