import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/hub/daily_topics_service.dart';

void main() {
  test('calendarDayKeyLocal format', () {
    final k = DailyTopicsService.calendarDayKeyLocal(
      DateTime(2026, 4, 18, 15, 30),
    );
    expect(k, '2026-04-18');
  });
}
