import type { Email } from './email-sender';

// The texts live in the API (not in the app, as other messages do) because an
// e-mail never goes through the app. Portuguese, plain text.

const SIGNATURE = '\n\nAbraço,\nPlantAí';

function greeting(name: string): string {
  return `Olá, ${name}!`;
}

/** The 6-digit code that confirms the e-mail of a new account. */
export function signupCodeEmail(name: string, code: string): Email {
  return {
    template: 'signup-code',
    subject: `${code} é o seu código do PlantAí`,
    text:
      `${greeting(name)}\n\n` +
      `Use este código para confirmar o seu e-mail no PlantAí:\n\n` +
      `${code}\n\n` +
      'Ele vale por 15 minutos. Se não foi você que criou a conta, ' +
      'pode ignorar este e-mail.' +
      SIGNATURE,
  };
}

/**
 * Sent instead of a code when someone signs up with the e-mail of a confirmed
 * account, so the answer to the sign-up never tells whether the e-mail is in use.
 */
export function accountExistsEmail(name: string): Email {
  return {
    template: 'account-exists',
    subject: 'Você já tem uma conta no PlantAí',
    text:
      `${greeting(name)}\n\n` +
      'Alguém tentou criar uma conta no PlantAí com este e-mail, mas você já ' +
      'tem uma. Para entrar, use a sua senha ou o Google.\n\n' +
      'Se esqueceu a senha, toque em "Entrar com e-mail" e depois em ' +
      '"Esqueci a senha" para criar uma nova.\n\n' +
      'Se não foi você, pode ignorar este e-mail: nada mudou na sua conta.' +
      SIGNATURE,
  };
}

/** The 6-digit code that lets the User set a new password. */
export function passwordResetCodeEmail(name: string, code: string): Email {
  return {
    template: 'password-reset-code',
    subject: `${code} é o seu código para trocar a senha do PlantAí`,
    text:
      `${greeting(name)}\n\n` +
      'Use este código para criar uma senha nova no PlantAí:\n\n' +
      `${code}\n\n` +
      'Ele vale por 15 minutos. Se não foi você que pediu, pode ignorar este ' +
      'e-mail: a sua senha continua a mesma.' +
      SIGNATURE,
  };
}
