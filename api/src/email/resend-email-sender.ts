import type { Email, EmailSender } from './email-sender';

const RESEND_EMAILS_URL = 'https://api.resend.com/emails';

export interface ResendOptions {
  apiKey: string;
  /** `EMAIL_FROM`, such as `PlantAí <onboarding@resend.dev>`. */
  from: string;
  /** Injected in tests; the global `fetch` otherwise. */
  fetch?: typeof fetch;
}

export class EmailNotSentError extends Error {
  override readonly name = 'EmailNotSentError';
}

/** Sends e-mail through the Resend HTTP API (https://resend.com/docs/api-reference/emails/send-email). */
export class ResendEmailSender implements EmailSender {
  private readonly fetch: typeof fetch;

  constructor(private readonly options: ResendOptions) {
    this.fetch = options.fetch ?? fetch;
  }

  async send(to: string, email: Email): Promise<void> {
    const response = await this.fetch(RESEND_EMAILS_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.options.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.options.from,
        to: [to],
        subject: email.subject,
        text: email.text,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      // The body names the problem (an unverified domain, for instance) and
      // never carries the e-mail itself.
      throw new EmailNotSentError(
        `Resend answered ${String(response.status)} for the ${email.template} e-mail: ${await response.text()}`,
      );
    }
  }
}
