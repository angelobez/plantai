import type { Context } from 'aws-lambda';
import { type LambdaHandler, lambdaEntry } from './lambda-entry';

const context = {} as Context;

describe('lambdaEntry', () => {
  it('starts once per cold start, not per invocation', async () => {
    let starts = 0;
    const handler = lambdaEntry(() => {
      starts += 1;
      const answer: LambdaHandler<string, string> = (event) =>
        Promise.resolve(`handled ${event}`);
      return Promise.resolve(answer);
    });

    const answers = await Promise.all([
      handler('a', context),
      handler('b', context),
    ]);
    const later = await handler('c', context);

    expect(starts).toBe(1);
    expect(answers).toEqual(['handled a', 'handled b']);
    expect(later).toBe('handled c');
  });

  it('takes no callback, which the Node.js 24 runtime refuses to load', () => {
    const handler = lambdaEntry(() =>
      Promise.resolve(() => Promise.resolve('handled')),
    );

    // The runtime rejects every handler declaring 3 or more parameters.
    expect(handler.length).toBeLessThan(3);
  });
});
