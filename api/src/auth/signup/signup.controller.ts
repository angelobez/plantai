import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiResponse, ApiTags } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { AuthTokens } from '../auth-tokens.dto';
import { Public } from '../public.decorator';
import { LimitsEmailsSent } from '../rate-limits';
import { SignupRequest, VerifyEmailRequest } from './signup.dto';
import { SignupService } from './signup.service';

@ApiTags('Auth')
@Public()
@Controller('auth')
export class SignupController {
  constructor(private readonly signup: SignupService) {}

  @Post('signup')
  @LimitsEmailsSent()
  @HttpCode(202)
  @ApiResponse({
    status: 202,
    description:
      'No body. The same for a new, an unconfirmed and a confirmed e-mail; ' +
      'the e-mail sent (a code or "you already have an account") differs',
  })
  @ApiProblems('TOO_MANY_REQUESTS')
  async signUp(@Body() body: SignupRequest): Promise<void> {
    await this.signup.signUp(body);
  }

  @Post('verify-email')
  @HttpCode(200)
  @ZodResponse({ status: 200, type: AuthTokens })
  @ApiProblems('INVALID_CODE', 'TOO_MANY_REQUESTS')
  verifyEmail(@Body() body: VerifyEmailRequest): Promise<AuthTokens> {
    return this.signup.verifyEmail(body);
  }
}
