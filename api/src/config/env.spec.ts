import { parseEnv } from './env';

const validEnv = {
  DATABASE_URL: 'postgres://plantai:plantai@localhost:5432/plantai',
  PORT: '3000',
  MIN_APP_VERSION: '1.2.0',
};

describe('parseEnv', () => {
  it('returns the typed config for a valid environment', () => {
    expect(parseEnv(validEnv)).toEqual({
      DATABASE_URL: 'postgres://plantai:plantai@localhost:5432/plantai',
      PORT: 3000,
      MIN_APP_VERSION: '1.2.0',
    });
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
});
