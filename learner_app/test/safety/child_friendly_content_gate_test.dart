import 'package:flutter_test/flutter_test.dart';
import 'package:ikamva_lam/safety/child_friendly_content_gate.dart';

void main() {
  group('ChildFriendlyContentGate', () {
    test('evaluateTopicPhrase accepts school-safe topics', () async {
      expect(
        (await ChildFriendlyContentGate.evaluateTopicPhrase('school')).ok,
        isTrue,
      );
      expect(
        (await ChildFriendlyContentGate.evaluateTopicPhrase('  my family  '))
            .ok,
        isTrue,
      );
    });

    test('evaluateTopicPhrase rejects obvious profanity token', () async {
      final v =
          await ChildFriendlyContentGate.evaluateTopicPhrase('bad shit topic');
      expect(v.ok, isFalse);
      expect(v.violations.any((e) => e.contains('blocked')), isTrue);
    });

    test('evaluatePlainText rejects URL-like content', () async {
      final v = await ChildFriendlyContentGate.evaluatePlainText(
        'Open https://evil.test now',
      );
      expect(v.ok, isFalse);
      expect(v.violations, contains('text_url_or_email'));
    });

    test('evaluateJsonPayloadString scans nested strings', () async {
      final v = await ChildFriendlyContentGate.evaluateJsonPayloadString(
        '{"sentence":"This is damn wrong","answer":"x","options":["x","y","z"]}',
      );
      expect(v.ok, isFalse);
    });

    test('evaluateJsonPayloadString accepts clean cloze-shaped JSON', () async {
      final v = await ChildFriendlyContentGate.evaluateJsonPayloadString(
        '{"sentence":"I like ___ .","answer":"rice","options":["rice","milk","tea"]}',
      );
      expect(v.ok, isTrue);
    });
  });
}
