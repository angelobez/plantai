import { concurrencyQuotaProblem } from './concurrency-quota';

describe('concurrencyQuotaProblem', () => {
  it('accepts an account whose quota leaves 100 unreserved besides the 20', () => {
    expect(concurrencyQuotaProblem(120)).toBeUndefined();
    expect(concurrencyQuotaProblem(1000)).toBeUndefined();
  });

  it('explains how to ask for more quota when 20 cannot be reserved', () => {
    const problem = concurrencyQuotaProblem(10);

    expect(problem).toContain('Service Quotas');
    expect(problem).toContain('Concurrent executions');
    expect(problem).toContain('L-B99A9384');
    expect(problem).toContain('at least 120');
    expect(problem).toContain('is 10');
  });

  it('counts the 100 that AWS keeps unreserved', () => {
    expect(concurrencyQuotaProblem(119)).toBeDefined();
  });
});
