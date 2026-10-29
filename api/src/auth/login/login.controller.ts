import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { AuthTokens } from '../auth-tokens.dto';
import { Public } from '../public.decorator';
import { LoginRequest } from './login.dto';
import { LoginService } from './login.service';

@ApiTags('Auth')
@Public()
@Controller('auth')
export class LoginController {
  constructor(private readonly login: LoginService) {}

  @Post('login')
  @HttpCode(200)
  @ZodResponse({ status: 200, type: AuthTokens })
  @ApiProblems('INVALID_CREDENTIALS', 'EMAIL_NOT_VERIFIED')
  logIn(@Body() body: LoginRequest): Promise<AuthTokens> {
    return this.login.logIn(body);
  }
}
