import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { AuthTokens } from '../auth-tokens.dto';
import { Public } from '../public.decorator';
import { GoogleRequest } from './google.dto';
import { GoogleService } from './google.service';

@ApiTags('Auth')
@Public()
@Controller('auth')
export class GoogleController {
  constructor(private readonly google: GoogleService) {}

  @Post('google')
  @HttpCode(200)
  @ZodResponse({ status: 200, type: AuthTokens })
  @ApiProblems(
    'INVALID_CREDENTIALS',
    'GOOGLE_ACCOUNT_LINK_REFUSED',
    'TOO_MANY_REQUESTS',
  )
  signIn(@Body() body: GoogleRequest): Promise<AuthTokens> {
    return this.google.signIn(body);
  }
}
