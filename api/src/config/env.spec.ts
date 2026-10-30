import { parseEnv } from './env';

const validEnv = {
  DATABASE_URL: 'postgres://plantai:plantai@localhost:5432/plantai',
  PORT: '3000',
  MIN_APP_VERSION: '1.2.0',
  JWT_SECRET: 'a-test-secret-that-is-at-least-32-chars',
  GOOGLE_WEB_CLIENT_ID: 'web-client.apps.googleusercontent.com',
  EMAIL_FROM: 'PlantAí <onboarding@resend.dev>',
  S3_BUCKET: 'plantai-photos',
  S3_REGION: 'us-east-1',
  PLANTNET_API_KEY: 'plantnet-key',
  ANTHROPIC_API_KEY: 'sk-ant-test',
};

describe('parseEnv', () => {
  it('returns the typed config for a valid environment', () => {
    expect(parseEnv(validEnv)).toEqual({
      ...validEnv,
      PORT: 3000,
      CARE_GUIDE_MODEL: 'claude-sonnet-5-5',
    });
  });

  it('takes the care-guide model from CARE_GUIDE_MODEL when set', () => {
    expect(
      parseEnv({ ...validEnv, CARE_GUIDE_MODEL: 'claude-opus-5-5' })
        .CARE_GUIDE_MODEL,
    ).toBe('claude-opus-5-5');
    expect(
      parseEnv({ ...validEnv, CARE_GUIDE_MODEL: '' }).CARE_GUIDE_MODEL,
    ).toBe('claude-sonnet-5-5');
  });

  it('fails without ANTHROPIC_API_KEY', () => {
    expect(() =>
      parseEnv({ ...validEnv, ANTHROPIC_API_KEY: undefined }),
    ).toThrow(/ANTHROPIC_API_KEY/);
  });

  it('keeps the S3 emulator endpoint and its keys when they are set', () => {
    expect(
      parseEnv({
        ...validEnv,
        S3_ENDPOINT: 'http://localhost:9000',
        S3_ACCESS_KEY_ID: 'plantai',
        S3_SECRET_ACCESS_KEY: 'plantai-secret',
      }),
    ).toMatchObject({
      S3_ENDPOINT: 'http://localhost:9000',
      S3_ACCESS_KEY_ID: 'plantai',
      S3_SECRET_ACCESS_KEY: 'plantai-secret',
    });
  });

  it('treats empty S3 endpoint and keys as unset, as on Lambda', () => {
    const env = parseEnv({
      ...validEnv,
      S3_ENDPOINT: '',
      S3_ACCESS_KEY_ID: '',
      S3_SECRET_ACCESS_KEY: '',
    });
    expect(env.S3_ENDPOINT).toBeUndefined();
    expect(env.S3_ACCESS_KEY_ID).toBeUndefined();
    expect(env.S3_SECRET_ACCESS_KEY).toBeUndefined();
  });

  it('fails when only one of the S3 keys is set', () => {
    expect(() =>
      parseEnv({ ...validEnv, S3_ACCESS_KEY_ID: 'plantai' }),
    ).toThrow(/S3_SECRET_ACCESS_KEY/);
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

  it.each([
    'GOOGLE_WEB_CLIENT_ID',
    'EMAIL_FROM',
    'JWT_SECRET',
    'S3_BUCKET',
    'S3_REGION',
    'PLANTNET_API_KEY',
  ])('fails when %s is missing', (name) => {
    expect(() => parseEnv({ ...validEnv, [name]: undefined })).toThrow(
      new RegExp(name),
    );
  });

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
