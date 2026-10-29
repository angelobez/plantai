import { Inject, Injectable, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import semver from 'semver';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import { DomainError } from '../errors/domain-error';
import { isSemanticVersion } from '../semantic-version';

const HEADER = 'X-App-Version';

/**
 * Compares the app's `X-App-Version` with `MIN_APP_VERSION`. Older apps get
 * `426 APP_UPDATE_REQUIRED`; requests without the header (curl, the future
 * `/docs`) pass.
 */
@Injectable()
export class AppVersionMiddleware implements NestMiddleware {
  constructor(@Inject(ENV) private readonly env: Env) {}

  use(request: Request, _response: Response, next: NextFunction): void {
    const version = request.header(HEADER);
    if (version === undefined) {
      next();
      return;
    }

    if (!isSemanticVersion(version)) {
      throw new DomainError('VALIDATION_FAILED', {
        errors: [
          { path: HEADER, message: 'must be a semantic version like 1.2.3' },
        ],
      });
    }
    if (semver.lt(version, this.env.MIN_APP_VERSION)) {
      throw new DomainError('APP_UPDATE_REQUIRED');
    }
    next();
  }
}
