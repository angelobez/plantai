import { parseEnv } from './env';

const validEnv = {
  DATABASE_URL: 'postgres://plantai:plantai@localhost:5432/plantai',
  PORT: '3000',
  MIN_APP_VERSION: '1.2.0',
  JWT_SECRET: 'a-test-secret-that-is-at-least-32-chars',
  GOOGLE_WEB_CLIENT_ID: 'web-client.apps.googleusercontent.com',
  EMAIL_FROM: 'PlantAí <onboarding@resend.dev>',
};

describe('parseEnv', () => {
  it('returns the typed config for a valid environment', () => {
    expect(parseEnv(validEnv)).toEqual({
      DATABASE_URL: 'postgres://plantai:plantai@localhost:5432/plantai',
      PORT: 3000,
      MIN_APP_VERSION: '1.2.0',
      JWT_SECRET: 'a-test-secret-that-is-at-least-32-chars',
      GOOGLE_WEB_CLIENT_ID: 'web-client.apps.googleusercontent.com',
      EMAIL_FROM: 'PlantAí <onboarding@resend.dev>',
    });
  });

  it('keeps RESEND_API_KEY when it is set', () => {
    expect(parseEnv({ ...validEnv, RESEND_API_KEY: 're_123' })).toMatchObject({
      RESEND_API_KEY: 're_123',
    });
  });

  it('treats an empty RESEND_API_KEY as unset, so e-mails go to the log', () => {
    expect(
      parseEnv({ ...validEnv, RESEND_API_KEY: '' }).RESEND_API_KEY,
    ).toBeUndefined();
  });

  it('rejects a JWT_SECRET shorter than 32 characters', () => {
    expect(() => parseEnv({ ...validEnv, JWT_SECRET: 'short' })).toThrow(
      /JWT_SECRET/,
    );
  });

  it.each(['GOOGLE_WEB_CLIENT_ID', 'EMAIL_FROM', 'JWT_SECRET'])(
    'fails when %s is missing',
    (name) => {
      expect(() => parseEnv({ ...validEnv, [name]: undefined })).toThrow(
        new RegExp(name),
      );
    },
  );

  it('fails naming the missing variable', () => {
    expect(() => parseEnv({ ...validEnv, DATABASE_URL: undefined })).toThrow(
      /DATABASE_URL/,
    );
  });

  it('fails naming every invalid variable at once', () => {
    expect(() =>
      parseEnv({ ...validEnv, PORT: 'abc', MIN_APP_VERSION: 'latest' }),
    ).toThrow(/PORT[\s\S]*MIN_APP_VERSION/);
  });

  it.each(['1.2.0-beta.1', '1.2.0+7'])(
    'accepts the semantic version %p as MIN_APP_VERSION',
    (version) => {
      expect(parseEnv({ ...validEnv, MIN_APP_VERSION: version })).toMatchObject(
        { MIN_APP_VERSION: version },
      );
    },
  );

  it.each(['v1.2.0', '1.2'])('rejects %p as MIN_APP_VERSION', (version) => {
    expect(() => parseEnv({ ...validEnv, MIN_APP_VERSION: version })).toThrow(
      /MIN_APP_VERSION/,
    );
  });
});
