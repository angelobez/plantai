import type {
  Email,
  EmailSender,
  EmailTemplate,
} from '../../src/email/email-sender';
import { EmailNotSentError } from '../../src/email/resend-email-sender';

export interface SentEmail extends Email {
  to: string;
}

/**
 * Stands in for the real e-mail adapter: keeps every e-mail the API sends, so
 * a test can read the code from it, as a person would from the inbox.
 */
export class FakeOutbox implements EmailSender {
  readonly sent: SentEmail[] = [];

  /**
   * While true, every send fails the way the real adapter does when the
   * provider refuses the e-mail, and nothing is kept.
   */
  failing = false;

  send(to: string, email: Email): Promise<void> {
    if (this.failing) {
      return Promise.reject(
        new EmailNotSentError(
          `The outbox refused the ${email.template} e-mail`,
        ),
      );
    }
    this.sent.push({ to, ...email });
    return Promise.resolve();
  }

  /** The e-mails sent to [to], oldest first. */
  sentTo(to: string): SentEmail[] {
    return this.sent.filter((email) => email.to === to);
  }

  /** The last e-mail sent to [to]; fails the test when there is none. */
  lastTo(to: string, template?: EmailTemplate): SentEmail {
    const email = this.sentTo(to)
      .filter(
        (candidate) =>
          template === undefined || candidate.template === template,
      )
      .at(-1);
    if (!email)
      throw new Error(
        `No e-mail${template ? ` ${template}` : ''} sent to ${to}`,
      );
    return email;
  }

  /** The 6-digit code of the last e-mail to [to] (of [template], if given). */
  lastCodeTo(to: string, template?: EmailTemplate): string {
    const email = this.lastTo(to, template);
    const code = /\b(\d{6})\b/.exec(email.text)?.[1];
    if (!code) throw new Error(`The last e-mail to ${to} has no code`);
    return code;
  }

  clear(): void {
    this.sent.length = 0;
  }
}
