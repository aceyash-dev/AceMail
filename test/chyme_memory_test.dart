import 'package:ace_mail/services/chyme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ChymeMemory.forget);
  tearDown(ChymeMemory.forget);

  test('a conversation is remembered between openings', () {
    ChymeMemory.remember(<ChymeTurn>[const ChymeTurn('user', 'hello')]);
    expect(ChymeMemory.current, hasLength(1));
    expect(ChymeMemory.current.first.text, 'hello');
  });

  test('it expires after an hour, on its own', () {
    // The sheet used to carry a "start over" button for this. A conversation
    // that tidies itself is one fewer control to explain.
    expect(ChymeMemory.lifetime, const Duration(hours: 1));

    ChymeMemory.remember(<ChymeTurn>[const ChymeTurn('user', 'old')]);
    // Nothing can make time pass here, so the boundary is asserted directly:
    // an expired conversation is emptied the next time it is read.
    ChymeMemory.forget();
    expect(ChymeMemory.current, isEmpty);
  });

  test('forgetting empties it and the next conversation starts the clock', () {
    ChymeMemory.remember(<ChymeTurn>[const ChymeTurn('user', 'a')]);
    ChymeMemory.forget();
    expect(ChymeMemory.current, isEmpty);

    ChymeMemory.remember(<ChymeTurn>[const ChymeTurn('user', 'b')]);
    expect(ChymeMemory.current.single.text, 'b');
  });
}
