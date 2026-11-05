import { testEnv } from '../../test/support/env';
import { parseEnv } from './env';
import {
  loadSsmParameters,
  type ParameterPage,
  type ParameterReader,
  SSM_PARAMETER_PREFIX,
} from './ssm-parameters';

const PREFIX = '/plantai/production';

/**
 * The variables of a valid environment, as the SSM would hold them. `PORT`
 * is left out: the Lambda never listens on one, so it takes the default.
 */
const validParameters: Record<string, string> = Object.fromEntries(
  Object.entries(
    testEnv('postgres://plantai:secret@db.neon.test/plantai'),
  ).flatMap(([name, value]) =>
    name === 'PORT' ? [] : [[name, String(value)]],
  ),
);

/** A fake SSM that serves [parameters] under [PREFIX], [pageSize] at a time. */
function fakeSsm(parameters: Record<string, string>, pageSize = 10) {
  const entries = Object.entries(parameters);
  const calls: { path: string; nextToken: string | undefined }[] = [];
  const read: ParameterReader = (path, nextToken) => {
    calls.push({ path, nextToken });
    const start = nextToken === undefined ? 0 : Number(nextToken);
    const page = entries.slice(start, start + pageSize);
    const next = start + pageSize;
    const result: ParameterPage = {
      parameters: page.map(([name, value]) => ({
        name: `${PREFIX}/${name}`,
        value,
      })),
      nextToken: next < entries.length ? String(next) : undefined,
    };
    return Promise.resolve(result);
  };
  return { read, calls };
}

describe('loadSsmParameters', () => {
  it('puts every parameter under the prefix in the environment, ready for parseEnv', async () => {
    const ssm = fakeSsm(validParameters, 3);
    const source: Record<string, string | undefined> = {
      [SSM_PARAMETER_PREFIX]: PREFIX,
    };

    await loadSsmParameters(source, ssm.read);

    expect(source).toMatchObject(validParameters);
    expect(parseEnv(source)).toMatchObject({
      DATABASE_URL: 'postgres://plantai:secret@db.neon.test/plantai',
      ANTHROPIC_API_KEY: validParameters.ANTHROPIC_API_KEY,
    });
    // Every page was read, all under the prefix.
    expect(ssm.calls.map((call) => call.path)).toEqual(
      Array<string>(Math.ceil(Object.keys(validParameters).length / 3)).fill(
        PREFIX,
      ),
    );
  });

  it('accepts a prefix with a trailing slash', async () => {
    const ssm = fakeSsm({ JWT_SECRET: 'a-secret-that-is-at-least-32-chars' });
    const source: Record<string, string | undefined> = {
      [SSM_PARAMETER_PREFIX]: `${PREFIX}/`,
    };

    await loadSsmParameters(source, ssm.read);

    expect(ssm.calls[0]?.path).toBe(PREFIX);
    expect(source.JWT_SECRET).toBe('a-secret-that-is-at-least-32-chars');
  });

  it('never calls the SSM without the prefix, leaving the environment as it was', async () => {
    const ssm = fakeSsm(validParameters);
    const source: Record<string, string | undefined> = { PORT: '3000' };

    await loadSsmParameters(source, ssm.read);

    expect(ssm.calls).toEqual([]);
    expect(source).toEqual({ PORT: '3000' });
  });

  it('treats an empty prefix as unset', async () => {
    const ssm = fakeSsm(validParameters);

    await loadSsmParameters({ [SSM_PARAMETER_PREFIX]: '' }, ssm.read);

    expect(ssm.calls).toEqual([]);
  });

  it('leaves a missing parameter to fail parseEnv with its usual message', async () => {
    const parameters: Record<string, string> = { ...validParameters };
    delete parameters.ANTHROPIC_API_KEY;
    const source: Record<string, string | undefined> = {
      [SSM_PARAMETER_PREFIX]: PREFIX,
    };

    await loadSsmParameters(source, fakeSsm(parameters).read);

    expect(() => parseEnv(source)).toThrow(
      'Invalid environment variables:\n  ANTHROPIC_API_KEY:',
    );
  });
});
