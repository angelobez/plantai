import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/donation_profile/brazilian_phone.dart';

void main() {
  group('formatBrazilianPhone', () {
    for (final (input, expected) in [
      ('', ''),
      ('1', '(1'),
      ('11', '(11'),
      ('119', '(11) 9'),
      ('119876', '(11) 9876'),
      ('1198765', '(11) 9876-5'),
      ('1133334444', '(11) 3333-4444'),
      ('11987654321', '(11) 98765-4321'),
      ('(11) 98765-4321', '(11) 98765-4321'),
      ('11 98765 4321', '(11) 98765-4321'),
      ('+55 11 98765-4321', '+55 (11) 98765-4321'),
      ('5511987654321', '+55 (11) 98765-4321'),
      ('+5511987654321', '+55 (11) 98765-4321'),
      // DDD 55 (Rio Grande do Sul) without the country code.
      ('55987654321', '(55) 98765-4321'),
      ('119876543210000', '(11) 98765-4321'),
      ('abc', ''),
    ]) {
      test('$input → $expected', () {
        expect(formatBrazilianPhone(input), expected);
      });
    }
  });

  group('whatsappNumber', () {
    for (final (input, expected) in [
      ('(11) 98765-4321', '5511987654321'),
      ('+55 (11) 98765-4321', '5511987654321'),
      ('(11) 3333-4444', '551133334444'),
      ('(55) 98765-4321', '5555987654321'),
      ('', null),
      ('9876-5432', null),
      ('(11', null),
    ]) {
      test('$input → $expected', () {
        expect(whatsappNumber(input), expected);
      });
    }
  });

  test('displayPhone shows an E.164 number with the mask', () {
    expect(displayPhone('+5511987654321'), '(11) 98765-4321');
    expect(displayPhone('+5555987654321'), '(55) 98765-4321');
  });

  test(
    'the input formatter masks what is typed and keeps the cursor at the end',
    () {
      const formatter = BrazilianPhoneInputFormatter();

      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '11987654321',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(value.text, '(11) 98765-4321');
      expect(value.selection, const TextSelection.collapsed(offset: 15));
    },
  );
}
