import { API_RESERVED_CONCURRENCY } from './api-stack';
import { STACK_REGION } from './stack-config';

/** Lambda never lets reservations take the last 100 of the account's quota. */
export const MIN_UNRESERVED_CONCURRENCY = 100;

/** The quota "Concurrent executions" of Lambda in Service Quotas. */
export const CONCURRENCY_QUOTA_CODE = 'L-B99A9384';

/**
 * Why the stack cannot reserve {@link API_RESERVED_CONCURRENCY} executions in
 * an account whose concurrency quota is [quota], or `undefined` when it can.
 * New accounts start with a reduced quota (US 42, ADR 0004).
 */
export function concurrencyQuotaProblem(quota: number): string | undefined {
  const needed = MIN_UNRESERVED_CONCURRENCY + API_RESERVED_CONCURRENCY;
  if (quota >= needed) return undefined;
  return [
    `The Lambda concurrency quota of this account is ${String(quota)}, so the API cannot reserve ${String(API_RESERVED_CONCURRENCY)} executions:`,
    `AWS keeps ${String(MIN_UNRESERVED_CONCURRENCY)} unreserved, so the quota must be at least ${String(needed)}.`,
    `Ask for more in Service Quotas: AWS Lambda > "Concurrent executions" (${CONCURRENCY_QUOTA_CODE}) in ${STACK_REGION},`,
    `https://${STACK_REGION}.console.aws.amazon.com/servicequotas/home/services/lambda/quotas/${CONCURRENCY_QUOTA_CODE}`,
    'and deploy again once the request is approved.',
  ].join('\n');
}
