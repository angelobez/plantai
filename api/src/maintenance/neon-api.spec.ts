import { NeonApiError, neonApiClient } from './neon-api';

/** A fetch that answers [status] with [body] and keeps the requests. */
function fakeFetch(status: number, body: unknown) {
  const requests: { url: string; init: RequestInit | undefined }[] = [];
  const fetch = (input: string | URL | Request, init?: RequestInit) => {
    requests.push({
      url: input instanceof Request ? input.url : input.toString(),
      init,
    });
    return Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  };
  return { fetch, requests };
}

const project = {
  project: {
    id: 'plain-sun-123456',
    name: 'plantai',
    compute_time_seconds: 290_160,
    active_time_seconds: 1_160_640,
    consumption_period_start: '2026-11-01T00:00:00Z',
    consumption_period_end: '2026-12-01T00:00:00Z',
  },
};

describe('neonApiClient', () => {
  it('reads the compute time of the billing cycle from GET /projects/{id}', async () => {
    const { fetch, requests } = fakeFetch(200, project);
    const neon = neonApiClient({
      apiKey: 'neon-key',
      projectId: 'plain-sun-123456',
      fetch,
    });

    await expect(neon.projectUsage()).resolves.toEqual({
      computeTimeSeconds: 290_160,
      consumptionPeriodStart: '2026-11-01T00:00:00Z',
    });
    expect(requests).toHaveLength(1);
    expect(requests[0]?.url).toBe(
      'https://console.neon.tech/api/v2/projects/plain-sun-123456',
    );
    expect(new Headers(requests[0]?.init?.headers).get('Authorization')).toBe(
      'Bearer neon-key',
    );
  });

  it('fails on an error answer, without the key in the message', async () => {
    const { fetch } = fakeFetch(401, { message: 'authorization failed' });
    const neon = neonApiClient({
      apiKey: 'neon-key',
      projectId: 'plain-sun-123456',
      fetch,
    });

    const failure = neon.projectUsage();
    await expect(failure).rejects.toThrow(NeonApiError);
    await expect(failure).rejects.toThrow(/401/);
    await expect(failure).rejects.not.toThrow(/neon-key/);
  });

  it('fails on an answer without the usage fields', async () => {
    const { fetch } = fakeFetch(200, { project: { id: 'plain-sun-123456' } });
    const neon = neonApiClient({
      apiKey: 'neon-key',
      projectId: 'plain-sun-123456',
      fetch,
    });

    await expect(neon.projectUsage()).rejects.toThrow(NeonApiError);
  });

  it('fails when Neon cannot be reached', async () => {
    const neon = neonApiClient({
      apiKey: 'neon-key',
      projectId: 'plain-sun-123456',
      fetch: () => Promise.reject(new TypeError('fetch failed')),
    });

    await expect(neon.projectUsage()).rejects.toThrow(/fetch failed/);
  });
});
