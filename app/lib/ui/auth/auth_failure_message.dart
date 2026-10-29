import '../../domain/models/auth_failure.dart';

/// The message an entry screen shows for [failure], in Portuguese.
///
/// A screen whose flow gives a code another meaning (Login, for
/// `emailNotVerified`, goes to the code screen instead) handles it before
/// falling back to this.
String authFailureMessage(AuthFailure failure) => switch (failure) {
  AuthFailure.invalidCode =>
    'Código errado ou vencido. Confira o e-mail ou peça um novo.',
  AuthFailure.invalidCredentials => 'E-mail ou senha incorretos.',
  AuthFailure.emailNotVerified =>
    'Confirme o seu e-mail com o código que enviamos.',
  AuthFailure.googleAccountLinkRefused =>
    'Este e-mail já tem conta no PlantAí. Entre com a sua senha.',
  AuthFailure.tooManyRequests =>
    'Muitas tentativas. Espere alguns minutos e tente de novo.',
  AuthFailure.validationFailed => 'Confira os dados e tente de novo.',
  AuthFailure.noConnection =>
    'Sem conexão com a internet. Confira a rede e tente de novo.',
  AuthFailure.updateRequired => 'Atualize o PlantAí para continuar.',
  AuthFailure.unknown => 'Algo deu errado. Tente de novo.',
};
