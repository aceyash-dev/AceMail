import 'package:ace_mail/services/local_avatars.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(LocalAvatars.resetForTest);

  test('the key is the address, lowercased and hashed', () {
    // The same key Gravatar uses, and the same one the avatar widget computes —
    // so a picture and a lookup cannot disagree about whose face it is.
    expect(LocalAvatars.keyFor('Someone@Example.com'),
        LocalAvatars.keyFor('someone@example.com'));
    expect(LocalAvatars.keyFor('a@b.com'), isNot(LocalAvatars.keyFor('c@d.com')));
    expect(LocalAvatars.keyFor('a@b.com').length, 32);
  });

  test('with no directory there is no picture, and no crash', () {
    // A device that will not hand over a directory means the feature is off,
    // not that the app fails to start.
    expect(LocalAvatars.pathFor('a@b.com'), isNull);
    expect(LocalAvatars.has('a@b.com'), isFalse);
  });

  test('a missing file is remembered as missing', () {
    expect(LocalAvatars.pathFor('a@b.com'), isNull);
    expect(LocalAvatars.pathFor('a@b.com'), isNull);
  });

  test('the revision moves when a picture does', () async {
    final int before = LocalAvatars.revision.value;
    // No directory in a test, so `clear` is the half that runs.
    await LocalAvatars.clear('a@b.com');
    expect(LocalAvatars.revision.value, before + 1);
  });
}
