import { createEmailSender } from './email.module';
import { signupCodeEmail } from './emails';
import { LogEmailSender } from './log-email-sender';
import { EmailNotSentError, ResendEmailSender } from './resend-email-sender';

const env = {
  DATABASE_URL: 'postgres://unused:unused@localhost:1/unused',
  PORT: 0,
  MIN_APP_VERSION: '0.0.0',
  JWT_SECRET: 'a-test-secret-that-is-at-least-32-chars',
  GOOGLE_WEB_CLIENT_ID: 'web-client',
  EMAIL_FROM: 'PlantAí <onboarding@resend.dev>',
  S3_BUCKET: 'unused',
  S3_REGION: 'us-east-1',
  PLANTNET_API_KEY: 'unused',
};

describe('createEmailSender', () => {
  it('writes e-mails to the log without RESEND_API_KEY', () => {
    expect(createEmailSender(env)).toBeInstanceOf(LogEmailSender);
  });

  it('sends through Resend with RESEND_API_KEY', () => {
    expect(
      createEmailSender({ ...env, RESEND_API_KEY: 're_123' }),
    ).toBeInstanceOf(ResendEmailSender);
  });
});

describe('ResendEmailSender', () => {
  const email = signupCodeEmail('Marina', '123456');

  it('posts the e-mail to Resend with the key and EMAIL_FROM', async () => {
    const fetch = jest.fn<
      Promise<Response>,
      Parameters<typeof globalThis.fetch>
    >(() => Promise.resolve(new Response('{"id":"1"}', { status: 200 })));
    const sender = new ResendEmailSender({
      apiKey: 're_123',
      from: 'PlantAí <onboarding@resend.dev>',
      fetch,
    });

    await sender.send('marina@email.com', email);

    const [url, init] = fetch.mock.calls[0] ?? [];
    expect(url).toBe('https://api.resend.com/emails');
    expect(init?.method).toBe('POST');
    expect(init?.headers).toMatchObject({ Authorization: 'Bearer re_123' });
    expect(JSON.parse(init?.body as string)).toEqual({
      from: 'PlantAí <onboarding@resend.dev>',
      to: ['marina@email.com'],
      subject: email.subject,
      text: email.text,
    });
  });

  it('fails when Resend refuses the e-mail', async () => {
    const sender = new ResendEmailSender({
      apiKey: 're_123',
      from: 'PlantAí <onboarding@resend.dev>',
      fetch: () =>
        Promise.resolve(new Response('{"message":"domain"}', { status: 403 })),
    });

    await expect(sender.send('marina@email.com', email)).rejects.toThrow(
      EmailNotSentError,
    );
  });
});

describe('the e-mail texts', () => {
  it('are in Portuguese and carry the code', () => {
    const email = signupCodeEmail('Marina', '042137');
    expect(email.subject).toContain('042137');
    expect(email.text).toContain('Olá, Marina!');
    expect(email.text).toContain('042137');
    expect(email.text).toContain('15 minutos');
  });
});
