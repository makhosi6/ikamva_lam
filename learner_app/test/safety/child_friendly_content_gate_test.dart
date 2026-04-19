import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/safety/child_friendly_content_gate.dart';

void main() {
  group('ChildFriendlyContentGate', () {
    test('evaluateTopicPhrase accepts school-safe topics', () {
      expect(
        ChildFriendlyContentGate.evaluateTopicPhrase('school').ok,
        isTrue,
      );
      expect(
        ChildFriendlyContentGate.evaluateTopicPhrase('  my family  ').ok,
        isTrue,
      );
    });

    test('evaluateTopicPhrase rejects obvious profanity token', () {
      final v = ChildFriendlyContentGate.evaluateTopicPhrase('bad shit topic');
      expect(v.ok, isFalse);
      expect(v.violations.any((e) => e.contains('blocked')), isTrue);
    });

    test('evaluatePlainText rejects URL-like content', () {
      final v = ChildFriendlyContentGate.evaluatePlainText(
        'Open https://evil.test now',
      );
      expect(v.ok, isFalse);
      expect(v.violations, contains('text_url_or_email'));
    });

    test('evaluateJsonPayloadString scans nested strings', () {
      final v = ChildFriendlyContentGate.evaluateJsonPayloadString(
        '{"sentence":"This is damn wrong","answer":"x","options":["x","y","z"]}',
      );
      expect(v.ok, isFalse);
    });

    test('evaluateJsonPayloadString accepts clean cloze-shaped JSON', () {
      final v = ChildFriendlyContentGate.evaluateJsonPayloadString(
        '{"sentence":"I like ___ .","answer":"rice","options":["rice","milk","tea"]}',
      );
      expect(v.ok, isTrue);
    });
  });
}
