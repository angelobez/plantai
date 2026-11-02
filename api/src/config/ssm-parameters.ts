import { GetParametersByPathCommand, SSMClient } from '@aws-sdk/client-ssm';

/**
 * The variable that holds the SSM Parameter Store path of the secrets, such
 * as `/plantai/production`. Set only on the Lambda functions; unset (local,
 * `dev:phone`, tests), nothing is read from the SSM.
 */
export const SSM_PARAMETER_PREFIX = 'SSM_PARAMETER_PREFIX';

export interface ParameterPage {
  parameters: { name: string; value: string }[];
  nextToken?: string;
}

/** Reads one page of the decrypted parameters directly under [path]. */
export type ParameterReader = (
  path: string,
  nextToken: string | undefined,
) => Promise<ParameterPage>;

/** The real reader: `GetParametersByPath`, decrypting the `SecureString`s. */
export function ssmParameterReader(
  client: SSMClient = new SSMClient({}),
): ParameterReader {
  return async (path, nextToken) => {
    const output = await client.send(
      new GetParametersByPathCommand({
        Path: path,
        Recursive: false,
        WithDecryption: true,
        NextToken: nextToken,
      }),
    );
    return {
      parameters: (output.Parameters ?? []).flatMap(({ Name, Value }) =>
        Name === undefined || Value === undefined
          ? []
          : [{ name: Name, value: Value }],
      ),
      nextToken: output.NextToken,
    };
  };
}

/**
 * Copies every parameter under the prefix in `SSM_PARAMETER_PREFIX` into
 * [target], named after the last segment of its path
 * (`/plantai/production/DATABASE_URL` becomes `DATABASE_URL`), overriding
 * what is there. Call it once per cold start, before {@link loadEnv}, which
 * then validates the result as usual. Without the prefix it does nothing.
 */
export async function loadSsmParameters(
  target: Record<string, string | undefined> = process.env,
  readParameters?: ParameterReader,
): Promise<void> {
  const prefix = target[SSM_PARAMETER_PREFIX]?.replace(/\/+$/, '');
  if (!prefix) return;

  const read = readParameters ?? ssmParameterReader();
  let nextToken: string | undefined;
  do {
    const page = await read(prefix, nextToken);
    for (const { name, value } of page.parameters) {
      target[name.slice(prefix.length + 1)] = value;
    }
    nextToken = page.nextToken;
  } while (nextToken !== undefined);
}
