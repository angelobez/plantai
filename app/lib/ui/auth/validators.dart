// Local checks of the entry screens, run before calling the API. Each returns
// the message to show under the field, or null when the value is fine. The
// limits match the API's (docs/spec/modelo-de-dados-e-api.md).

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _code = RegExp(r'^\d{6}$');

const nameMaxLength = 80;
const passwordMinLength = 8;
const passwordMaxLength = 128;
const codeLength = 6;

String? validateName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Informe o seu nome.';
  if (trimmed.length > nameMaxLength) {
    return 'Use até $nameMaxLength caracteres.';
  }
  return null;
}

String? validateEmail(String email) =>
    _email.hasMatch(email.trim()) ? null : 'Informe um e-mail válido.';

String? validatePassword(String password) {
  if (password.length < passwordMinLength) {
    return 'A senha precisa ter pelo menos $passwordMinLength caracteres.';
  }
  if (password.length > passwordMaxLength) {
    return 'Use até $passwordMaxLength caracteres.';
  }
  return null;
}

String? validateCode(String code) =>
    _code.hasMatch(code) ? null : 'Digite os $codeLength dígitos do código.';
