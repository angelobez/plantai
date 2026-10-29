import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AccessTokens } from './access-tokens';
import { AuthGuard } from './auth.guard';
import { EmailCodes } from './email-codes';
import { LogoutController } from './logout/logout.controller';
import { LogoutService } from './logout/logout.service';
import { Sessions } from './sessions';
import { SignupController } from './signup/signup.controller';
import { SignupService } from './signup/signup.service';

/**
 * Authentication (ADR 0001). The rest of the API only uses three pieces: the
 * global {@link AuthGuard} (Bearer on every route), `@Public()` and
 * `@CurrentUser()`.
 *
 * Each way in has its own folder with controller, service and DTOs (`signup/`
 * for now), sharing {@link Sessions} (tokens) and {@link EmailCodes}.
 */
@Module({
  controllers: [SignupController, LogoutController],
  providers: [
    AccessTokens,
    EmailCodes,
    LogoutService,
    Sessions,
    SignupService,
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
})
export class AuthModule {}
