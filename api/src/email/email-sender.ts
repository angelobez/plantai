/** Which e-mail it is; tests and logs tell them apart by it. */
export type EmailTemplate =
  'signup-code' | 'account-exists' | 'password-reset-code';

/** An e-mail ready to send, built by one of the functions in `emails.ts`. */
export interface Email {
  template: EmailTemplate;
  subject: string;
  text: string;
}

/**
 * The port for sending e-mail. The e-mail module picks the adapter: Resend
 * with `RESEND_API_KEY`, the API log without it; tests swap in a fake outbox.
 *
 * An abstract class rather than an interface, so it doubles as the Nest
 * injection token.
 */
export abstract class EmailSender {
  abstract send(to: string, email: Email): Promise<void>;
}
