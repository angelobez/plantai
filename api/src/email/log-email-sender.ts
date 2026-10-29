import { Logger } from '@nestjs/common';
import type { Email, EmailSender } from './email-sender';

/**
 * Writes the e-mail to the API log instead of sending it. Used when there is
 * no `RESEND_API_KEY`, so the sign-up code can be read from the terminal in
 * local development. It does log the code: never use it in a deployed API.
 */
export class LogEmailSender implements EmailSender {
  private readonly logger = new Logger('Email');

  send(to: string, email: Email): Promise<void> {
    this.logger.log(
      `Not sent (no RESEND_API_KEY). To: ${to}\nSubject: ${email.subject}\n\n${email.text}`,
    );
    return Promise.resolve();
  }
}
