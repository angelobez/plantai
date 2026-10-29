import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ENV } from '../config/config.module';
import { AccessTokens } from './access-tokens';
import { AuthGuard } from './auth.guard';
import { EmailCodes } from './email-codes';
import { createGoogleTokenVerifier } from './google/google-auth-library-verifier';
import { GoogleController } from './google/google.controller';
import { GoogleService } from './google/google.service';
import { GoogleTokenVerifier } from './google/google-token-verifier';
import { LoginController } from './login/login.controller';
import { LoginService } from './login/login.service';
import { LogoutController } from './logout/logout.controller';
import { LogoutService } from './logout/logout.service';
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
  controllers: [
    SignupController,
    LoginController,
    RefreshController,
    LogoutController,
    GoogleController,
  ],
  providers: [
    AccessTokens,
    EmailCodes,
    LogoutService,
    Sessions,
    SignupService,
    LoginService,
    RefreshService,
    GoogleService,
    {
      provide: GoogleTokenVerifier,
      inject: [ENV],
      useFactory: createGoogleTokenVerifier,
    },
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
})
export class AuthModule {}
