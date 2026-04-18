import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/hub/daily_quest_ids.dart';

void main() {
  test('make and tryParse round-trip', () {
    const day = '2026-04-18';
    final id = DailyQuestIds.make(day, 'ice cream');
    expect(id, 'daily-2026-04-18-ice-cream');
    final parsed = DailyQuestIds.tryParse(id);
    expect(parsed, isNotNull);
    expect(parsed!.$1, day);
    expect(parsed.$2, 'ice cream');
  });

  test('seed quest id is not daily', () {
    expect(DailyQuestIds.tryParse('seed-quest-1'), isNull);
  });

  test('normalizeDayKey', () {
    expect(DailyQuestIds.normalizeDayKey('2026-04-18'), '2026-04-18');
    expect(DailyQuestIds.normalizeDayKey('bad'), isNull);
  });
}
