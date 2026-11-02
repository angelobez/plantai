import type { Context, Handler } from 'aws-lambda';
import { lambdaEntry } from './lambda-entry';

const context = {} as Context;
const noCallback = () => undefined;

describe('lambdaEntry', () => {
  it('starts once per cold start, not per invocation', async () => {
    let starts = 0;
    const handler = lambdaEntry(() => {
      starts += 1;
      const answer: Handler<string, string> = (event) =>
        Promise.resolve(`handled ${event}`);
      return Promise.resolve(answer);
    });

    const answers = await Promise.all([
      handler('a', context, noCallback),
      handler('b', context, noCallback),
    ]);
    const later: unknown = await handler('c', context, noCallback);

    expect(starts).toBe(1);
    expect(answers).toEqual(['handled a', 'handled b']);
    expect(later).toBe('handled c');
  });
});
