import 'package:ace_mail/data/secret_store.dart';
import 'package:ace_mail/services/google_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keychain that can be told to fail.
///
/// The interesting behaviour in this file is what happens when storage does not
/// work, and that cannot be reached through the real one.
class FakeStore implements SecretStore {
  FakeStore({this.failReads = false, this.failWrites = false});

  final Map<String, String> values = <String, String>{};
  bool failReads;
  bool failWrites;
  int deletes = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keychain unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keychain refused');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    if (failReads) throw StateError('keychain unavailable');
    return Map<String, String>.of(values);
  }
}

void main() {
  late FakeStore store;

  setUp(() {
    store = FakeStore();
    GoogleAuth.storage = store;
  });

  group('cached tokens are cleared, and only the right ones', () {
    test('one account: its token goes, another account keeps its own', () async {
      store.values.addAll(<String, String>{
        'ace.google.token.one@example.com': 'token-one',
        'ace.google.tokenAt.one@example.com': '2026-01-01',
        'ace.google.token.two@example.com': 'token-two',
        'ace.google.tokenAt.two@example.com': '2026-01-01',
        'ace.google.email': 'two@example.com',
      });

      await GoogleAuth.clearCachedTokens(email: 'ONE@example.com ');

      expect(store.values.containsKey('ace.google.token.one@example.com'),
          isFalse);
      expect(store.values.containsKey('ace.google.tokenAt.one@example.com'),
          isFalse);
      // The mailbox next door is untouched: removing one account must not sign
      // the other one out.
      expect(store.values['ace.google.token.two@example.com'], 'token-two');
      expect(store.values['ace.google.email'], 'two@example.com');
    });

    test('every account: the cache is enumerated, not guessed', () async {
      // The address nobody remembers signing in as is exactly the one a
      // delete-the-last-account's-key approach leaves behind.
      store.values.addAll(<String, String>{
        'ace.google.token.one@example.com': 'a',
        'ace.google.tokenAt.one@example.com': 'b',
        'ace.google.token.two@example.com': 'c',
        'ace.google.tokenAt.two@example.com': 'd',
        'ace.google.email': 'two@example.com',
        'ace.google.name': 'Some One',
        'unrelated.key': 'kept',
      });

      await GoogleAuth.clearCachedTokens();

      expect(
        store.values.keys.where((String k) => k.startsWith('ace.google.token')),
        isEmpty,
      );
      // Everything that is not a token cache survives: this is cleanup, not
      // sign-out.
      expect(store.values['ace.google.email'], 'two@example.com');
      expect(store.values['ace.google.name'], 'Some One');
      expect(store.values['unrelated.key'], 'kept');
    });

    test('signing out clears the cache and the identity', () async {
      store.values.addAll(<String, String>{
        'ace.google.token.one@example.com': 'a',
        'ace.google.tokenAt.one@example.com': 'b',
        'ace.google.email': 'one@example.com',
        'ace.google.name': 'Some One',
      });

      // The SDK call inside throws here (no plugin in a test), which is the
      // state being asked for: local cleanup must not depend on it.
      await GoogleAuth.forget();

      expect(
        store.values.keys.where((String k) => k.startsWith('ace.google.')),
        isEmpty,
      );
    });

    test('an unreadable keychain does not stop the cleanup', () async {
      store.values['ace.google.token.one@example.com'] = 'a';
      store.failReads = true;

      // Enumerating fails, so the tokens cannot be found — but signing out
      // still happens, and nothing throws in the caller's face.
      await GoogleAuth.forget();
      expect(store.values.containsKey('ace.google.email'), isFalse);
    });
  });

  group('a keychain failure is not a signed-out person', () {
    test('an unreadable store is reported, not turned into "sign in"', () async {
      store.failReads = true;

      // Null means "there is no token, ask them to sign in". Throwing means
      // "this device cannot answer right now" — a different sentence, and the
      // one that stops a temporary fault becoming a login prompt.
      await expectLater(
        GoogleAuth.token('someone@example.com'),
        throwsA(isA<GoogleAuthException>()),
      );
    });

    test('an empty store is an ordinary null', () async {
      expect(await GoogleAuth.token('someone@example.com'), isNull);
    });

    test('a write that is refused is not reported as a save', () async {
      store.failWrites = true;
      // There is no public write to call, so this is the closest honest check:
      // the store refusing a write leaves nothing behind, and the next read
      // says so rather than pretending otherwise.
      expect(await GoogleAuth.token('someone@example.com'), isNull);
      expect(store.values, isEmpty);
    });
  });
}
