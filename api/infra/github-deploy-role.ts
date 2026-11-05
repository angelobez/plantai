import { Stack } from 'aws-cdk-lib';
import {
  OidcProviderNative,
  PolicyStatement,
  Role,
  WebIdentityPrincipal,
} from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

const GITHUB_OIDC_ISSUER = 'token.actions.githubusercontent.com';

/**
 * The only token subject trusted: a job of angelobez/plantai that runs in its
 * `production` environment (the deploy job of .github/workflows/ci.yml).
 * The repository was created after 2026-07-15, so GitHub writes its `sub`
 * in the immutable format, with the owner and repository ids
 * (`gh api repos/angelobez/plantai/actions/oidc/customization/sub`); the
 * plain `repo:angelobez/plantai:...` would never match. A job with an
 * environment gets `...:environment:<name>` instead of `...:ref:<ref>`, so
 * the "only `main`" rule lives in the environment's deployment branch
 * policy, which admits only `main` (runbook, #92).
 */
export const GITHUB_DEPLOY_SUBJECT =
  'repo:angelobez@109678169/plantai@1426449697:environment:production';

/** The roles of `cdk bootstrap` (default qualifier) that a deploy uses. */
const CDK_BOOTSTRAP_ROLES = ['deploy', 'file-publishing', 'lookup'];

/**
 * The role GitHub Actions assumes through OIDC to run `npm run cdk:deploy`
 * (#93), with no AWS key stored in GitHub. It may only assume the CDK
 * bootstrap roles, which do the actual deploy. The stack creates it, so the
 * first deploy runs from the notebook.
 */
export class GithubDeployRole extends Construct {
  readonly role: Role;

  constructor(scope: Construct, id: string) {
    super(scope, id);
    const stack = Stack.of(this);

    // One per account and URL: the deploy fails if one exists already.
    const provider = new OidcProviderNative(this, 'GithubOidc', {
      url: `https://${GITHUB_OIDC_ISSUER}`,
      clientIds: ['sts.amazonaws.com'],
    });

    this.role = new Role(this, 'Role', {
      description:
        'GitHub Actions deploy of the API (production environment of angelobez/plantai)',
      assumedBy: new WebIdentityPrincipal(provider.oidcProviderArn, {
        StringEquals: {
          [`${GITHUB_OIDC_ISSUER}:aud`]: 'sts.amazonaws.com',
          [`${GITHUB_OIDC_ISSUER}:sub`]: GITHUB_DEPLOY_SUBJECT,
        },
      }),
    });

    this.role.addToPolicy(
      new PolicyStatement({
        actions: ['sts:AssumeRole'],
        resources: CDK_BOOTSTRAP_ROLES.map((name) =>
          stack.formatArn({
            service: 'iam',
            region: '',
            resource: 'role',
            resourceName: `cdk-hnb659fds-${name}-role-${stack.account}-${stack.region}`,
          }),
        ),
      }),
    );
    this.role.addToPolicy(
      new PolicyStatement({
        // infra/check-concurrency-quota.ts runs with this role's credentials.
        actions: ['lambda:GetAccountSettings'],
        resources: ['*'],
      }),
    );
  }
}
