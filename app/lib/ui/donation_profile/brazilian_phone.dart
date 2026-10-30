import 'package:flutter/services.dart';

/// The digits of a national number: the area code (2) and up to 9 more.
const _maxNationalDigits = 11;

/// [input]'s digits split into the country code (when it has `55` in front of
/// a full national number) and the national number, at most 11 digits.
({bool withCountryCode, String national}) _split(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  // A national number never passes 11 digits, so 55 in front of more is the
  // country code; with 11 or fewer it may be the area code 55 (RS).
  final withCountryCode =
      digits.length > _maxNationalDigits && digits.startsWith('55');
  final national = withCountryCode ? digits.substring(2) : digits;
  return (
    withCountryCode: withCountryCode,
    national: national.length > _maxNationalDigits
        ? national.substring(0, _maxNationalDigits)
        : national,
  );
}

/// [input] with the mask of a Brazilian phone, as it is typed:
/// `(11) 98765-4321`, `(11) 3333-4444`, or `+55 (11) 98765-4321` when it
/// starts with the country code. Anything but digits is dropped.
String formatBrazilianPhone(String input) {
  final (:withCountryCode, :national) = _split(input);
  final prefix = withCountryCode ? '+55 ' : '';
  if (national.isEmpty) return '';
  if (national.length <= 2) return '$prefix($national';
  final areaCode = national.substring(0, 2);
  final number = national.substring(2);
  // Mobiles have 9 digits (5-4); landlines, and a number still being typed,
  // 8 or fewer (4-4).
  final split = number.length > 8 ? 5 : 4;
  final formatted = number.length <= split
      ? number
      : '${number.substring(0, split)}-${number.substring(split)}';
  return '$prefix($areaCode) $formatted';
}

/// The digits `wa.me` takes for [input] (`5511987654321`): the country code
/// and a national number of 10 or 11 digits; null when [input] is not that
/// long. Only a check of the length: the API is the one that tells a mobile.
String? whatsappNumber(String input) {
  final (withCountryCode: _, :national) = _split(input);
  if (national.length < 10) return null;
  return '55$national';
}

/// An E.164 number of the API (`+5511987654321`) as the app shows it:
/// `(11) 98765-4321`.
String displayPhone(String e164) =>
    formatBrazilianPhone(e164.replaceFirst(RegExp(r'^\+55'), ''));

/// Masks the phone field with [formatBrazilianPhone] as the User types,
/// keeping the cursor at the end.
class BrazilianPhoneInputFormatter extends TextInputFormatter {
  const BrazilianPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatBrazilianPhone(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
