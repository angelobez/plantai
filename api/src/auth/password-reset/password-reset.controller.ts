import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiResponse, ApiTags } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { AuthTokens } from '../auth-tokens.dto';
import { Public } from '../public.decorator';
import { LimitsEmailsSent } from '../rate-limits';
import {
  PasswordResetConfirmRequest,
  PasswordResetRequest,
} from './password-reset.dto';
import { PasswordResetService } from './password-reset.service';

@ApiTags('Auth')
@Public()
@Controller('auth/password-reset')
export class PasswordResetController {
  constructor(private readonly passwordReset: PasswordResetService) {}

  @Post('request')
  @LimitsEmailsSent()
  @HttpCode(204)
  @ApiResponse({
    status: 204,
    description:
      'No body. The same with and without an account; only an account ' +
      'gets the e-mail with the code',
  })
  @ApiProblems('TOO_MANY_REQUESTS')
  async request(@Body() body: PasswordResetRequest): Promise<void> {
    await this.passwordReset.request(body);
  }

  @Post('confirm')
  @HttpCode(200)
  @ZodResponse({ status: 200, type: AuthTokens })
  @ApiProblems('INVALID_CODE', 'TOO_MANY_REQUESTS')
  confirm(@Body() body: PasswordResetConfirmRequest): Promise<AuthTokens> {
    return this.passwordReset.confirm(body);
  }
}
