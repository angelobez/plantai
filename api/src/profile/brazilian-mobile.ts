// The `max` metadata: the default (`min`) one cannot tell a mobile from a
// landline, so `getType()` would always be undefined.
import { parsePhoneNumberFromString } from 'libphonenumber-js/max';

/**
 * [input] as an E.164 Brazilian mobile number (`+5511987654321`), or null when
 * it is not one. Takes the area code with or without `+55`, masks and spaces.
 */
export function toBrazilianMobile(input: string): string | null {
  const phone = parsePhoneNumberFromString(input, 'BR');
  if (!phone?.isValid()) return null;
  if (phone.country !== 'BR' || phone.getType() !== 'MOBILE') return null;
  return phone.number;
}
