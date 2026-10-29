import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AccessTokens } from './access-tokens';
import { AuthGuard } from './auth.guard';
import { EmailCodes } from './email-codes';
import { LoginController } from './login/login.controller';
import { LoginService } from './login/login.service';
import { RefreshController } from './refresh/refresh.controller';
import { RefreshService } from './refresh/refresh.service';
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
  controllers: [SignupController, LoginController, RefreshController],
  providers: [
    AccessTokens,
    EmailCodes,
    Sessions,
    SignupService,
    LoginService,
    RefreshService,
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
})
export class AuthModule {}
