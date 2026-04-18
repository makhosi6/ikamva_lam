/// Stable quest ids for hub "daily topic" sessions (not stored in [quests] table).
abstract final class DailyQuestIds {
  static const prefix = 'daily-';

  /// [calendarDayKey] is `yyyy-MM-dd` (local calendar day).
  static String make(String calendarDayKey, String topic) {
    final slug = slugify(topic);
    if (slug.isEmpty) return '$prefix$calendarDayKey-topic';
    return '$prefix$calendarDayKey-$slug';
  }

  /// Returns `(dayKey, topic)` with [topic] normalized from the id slug.
  static (String dayKey, String topic)? tryParse(String questId) {
    if (!questId.startsWith(prefix)) return null;
    final rest = questId.substring(prefix.length);
    final re = RegExp(r'^(\d{4}-\d{2}-\d{2})-(.+)$');
    final m = re.firstMatch(rest);
    if (m == null) return null;
    final dayKey = m.group(1)!;
    final slug = m.group(2)!;
    if (slug.isEmpty) return null;
    final topic = slug.replaceAll('-', ' ').trim().toLowerCase();
    if (topic.isEmpty) return null;
    return (dayKey, topic);
  }

  static String slugify(String topic) {
    return topic
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String? normalizeDayKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ? raw : null;
  }

  static String normalizeTopicToken(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
