import 'dart:convert';

import 'package:ace_mail/models/contact.dart';
import 'package:ace_mail/util/addresses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a contact', () {
    test('shows the address when there is no name', () {
      const Contact contact = Contact(email: 'someone@example.com');
      expect(contact.label, 'someone@example.com');
      expect(contact.hasName, isFalse);
    });

    test('shows the name, and the address under it', () {
      const Contact contact =
          Contact(email: 'someone@example.com', name: 'Someone');
      expect(contact.label, 'Someone');
      expect(contact.hasName, isTrue);
    });

    test('a name equal to the address is not a name', () {
      const Contact contact =
          Contact(email: 'someone@example.com', name: 'someone@example.com');
      expect(contact.hasName, isFalse);
    });

    test('round-trips through JSON, writing only what is set', () {
      const Contact saved = Contact(
        email: 'someone@example.com',
        name: 'Someone',
        saved: true,
        count: 3,
      );
      final Map<String, dynamic> json = saved.toJson();
      expect(json['saved'], isTrue);
      expect(json['count'], 3);

      final Contact back = Contact.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back.email, saved.email);
      expect(back.name, saved.name);
      expect(back.saved, isTrue);
      expect(back.count, 3);

      // A seen-only contact writes neither flag.
      final Map<String, dynamic> plain =
          const Contact(email: 'a@b.com').toJson();
      expect(plain.containsKey('saved'), isFalse);
      expect(plain.containsKey('count'), isFalse);
    });

    test('survives a record with nothing in it', () {
      final Contact contact = Contact.fromJson(<String, dynamic>{});
      expect(contact.email, isEmpty);
      expect(contact.saved, isFalse);
      expect(contact.count, 0);
      expect(contact.lastSeen, isNull);
    });
  });

  group('machine addresses', () {
    test('are the ones that only send', () {
      for (final String address in <String>[
        'noreply@example.com',
        'no-reply@example.com',
        'donotreply@example.com',
        'mailer-daemon@example.com',
        'postmaster@example.com',
        'notifications@github.com',
        'newsletter@shop.example',
        'NoReply@Example.com',
      ]) {
        expect(isMachineAddress(address), isTrue, reason: address);
      }
    });

    test('leave people alone', () {
      for (final String address in <String>[
        'yash@example.com',
        'someone.real@example.com',
        'support@example.com', // a person answered the last one
        'info@mycompany.example',
        'reply@example.com',
      ]) {
        expect(isMachineAddress(address), isFalse, reason: address);
      }
    });
  });
}
