import 'package:ace_mail/util/otp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OtpDetector.find', () {
    test('finds a code the subject announces', () {
      expect(
        OtpDetector.find('Your verification code is 483920'),
        '483920',
      );
    });

    test('finds a code after a colon', () {
      expect(OtpDetector.find('Ace Mail login code: 7712'), '7712');
    });

    test('finds a code in a subject that leads with it', () {
      expect(OtpDetector.find('123456 is your one-time passcode'), '123456');
    });

    test('ignores a bare number with nothing to say it is a code', () {
      expect(OtpDetector.find('Your order 482913 has shipped'), isNull);
      expect(OtpDetector.find('Invoice 2024-0912'), isNull);
    });

    test('ignores a year', () {
      expect(OtpDetector.find('Verification of your 2024 statement'), isNull);
    });

    test('ignores the usual placeholder codes', () {
      expect(OtpDetector.find('Your code is 1234'), isNull);
      expect(OtpDetector.find('Your code is 0000'), isNull);
    });

    test('does not carve a code out of a longer number', () {
      expect(OtpDetector.find('Call 18005551234 for your code'), isNull);
      expect(OtpDetector.find('Card ending 4111111111111111 code'), isNull);
    });

    test('takes the code nearest the words that describe it', () {
      // Two numbers, one of them clearly the code.
      expect(
        OtpDetector.find('Order 998877 shipped. Your OTP is 445566'),
        '445566',
      );
    });

    test('an empty subject has nothing', () {
      expect(OtpDetector.find(''), isNull);
    });

    test('a six-digit code with no context is not shown', () {
      // A price, a reference, a phone extension — showing these as codes would
      // be worse than showing nothing.
      expect(OtpDetector.find('Receipt 334455 attached'), isNull);
    });
  });

  group('OtpDetector.looksLikeCodeMail', () {
    test('recognises the words that mean a code is inside', () {
      expect(OtpDetector.looksLikeCodeMail('Your verification code'), isTrue);
      expect(OtpDetector.looksLikeCodeMail('Sign in to your account'), isFalse);
      expect(OtpDetector.looksLikeCodeMail('One-time password'), isTrue);
    });
  });

  group('OtpDetector.findInBody', () {
    test('joins a code split by a quoted-printable soft break', () {
      expect(
        OtpDetector.findInBody('Your code is 4839=\r\n20 today'),
        '483920',
      );
    });

    test('ignores markup around the code', () {
      expect(
        OtpDetector.findInBody('<p>Your OTP is <b>556677</b></p>'),
        '556677',
      );
    });

    test('an empty body has nothing', () {
      expect(OtpDetector.findInBody(''), isNull);
    });
  });
}
