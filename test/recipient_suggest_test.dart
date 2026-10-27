import 'package:ace_mail/models/contact.dart';
import 'package:ace_mail/util/recipient_suggest.dart';
import 'package:flutter_test/flutter_test.dart';

const Contact ann = Contact(email: 'ann@example.com', name: 'Ann Example');
const Contact brian = Contact(email: 'brianna@example.org', name: 'Brianna');
const Contact bare = Contact(email: 'accounts@example.net');
const Contact savedAnn = Contact(
  email: 'ann@work.example',
  name: 'Ann Saved',
  saved: true,
);

void main() {
  group('the address being typed', () {
    test('is the text after the last separator', () {
      expect(RecipientSuggest.token('ann'), 'ann');
      expect(RecipientSuggest.token('a@b.com, bo'), 'bo');
      expect(RecipientSuggest.token('a@b.com; bo'), 'bo');
      expect(RecipientSuggest.token('a@b.com,'), '');
      expect(RecipientSuggest.token('  spaced  '), 'spaced');
    });

    test('the addresses already in the field are read out of it', () {
      expect(
        RecipientSuggest.addressesIn('Ann <Ann@Example.com>, c@d.com; e@f.com'),
        <String>{'ann@example.com', 'c@d.com', 'e@f.com'},
      );
      expect(RecipientSuggest.addressesIn(''), isEmpty);
    });
  });

  group('picking one', () {
    test('writes the name and the address when there is a name', () {
      expect(RecipientSuggest.format(ann), 'Ann Example <ann@example.com>');
      expect(RecipientSuggest.format(bare), 'accounts@example.net');
    });

    test('replaces the half-typed address and leaves a separator', () {
      expect(
        RecipientSuggest.replaceToken('ann', 'Ann <ann@example.com>'),
        'Ann <ann@example.com>, ',
      );
      expect(
        RecipientSuggest.replaceToken('a@b.com, br', 'Brianna <b@x.org>'),
        'a@b.com, Brianna <b@x.org>, ',
      );
      // Trailing space after a comma is normalised, not doubled.
      expect(
        RecipientSuggest.replaceToken('a@b.com, br', 'B <b@x.org>'),
        'a@b.com, B <b@x.org>, ',
      );
    });
  });

  group('what is worth offering', () {
    test('nothing for one character, or an empty field', () {
      expect(
        RecipientSuggest.forText('a', contacts: <Contact>[ann, brian]),
        isEmpty,
      );
      expect(RecipientSuggest.forText('', contacts: <Contact>[ann]), isEmpty);
    });

    test('matches on the name and on the address', () {
      expect(
        RecipientSuggest.forText('bri', contacts: <Contact>[ann, brian]).single,
        brian,
      );
      expect(
        RecipientSuggest.forText('ann@ex', contacts: <Contact>[ann, brian]).single,
        ann,
      );
    });

    test('a name that starts with what was typed comes first', () {
      // "Zoe" has nothing to do with "ann"; "Brianna" merely contains it.
      const Contact zoe = Contact(email: 'zoe@example.com', name: 'Zoe');
      final List<Contact> offered = RecipientSuggest.forText(
        'ann',
        contacts: <Contact>[zoe, savedAnn, ann],
      );
      // Both Anns start with "ann"; the saved one outranks the seen one.
      expect(offered.first, savedAnn);
      expect(offered, contains(ann));
      expect(offered, isNot(contains(zoe)));
    });

    test('somebody already in the field is not offered again', () {
      final List<Contact> offered = RecipientSuggest.forText(
        'Ann <ann@example.com>, an',
        contacts: <Contact>[ann, savedAnn],
      );
      expect(offered, isNot(contains(ann)));
      expect(offered, contains(savedAnn));
    });

    test('the addresses to exclude are never offered', () {
      final List<Contact> offered = RecipientSuggest.forText(
        'ann',
        contacts: <Contact>[ann, savedAnn],
        exclude: <String>{'ANN@work.example'},
      );
      expect(offered, <Contact>[ann]);
    });

    test('the list is capped', () {
      final List<Contact> many = <Contact>[
        for (int i = 0; i < 12; i++)
          Contact(email: 'person$i@example.com', name: 'Person $i'),
      ];
      expect(
        RecipientSuggest.forText('person', contacts: many).length,
        5,
      );
      expect(
        RecipientSuggest.forText('person', contacts: many, limit: 2).length,
        2,
      );
    });
  });
}
