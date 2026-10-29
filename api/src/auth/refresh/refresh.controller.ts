import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ZodResponse } from 'nestjs-zod';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { AuthTokens } from '../auth-tokens.dto';
import { Public } from '../public.decorator';
import { RefreshRequest } from './refresh.dto';
import { RefreshService } from './refresh.service';

@ApiTags('Auth')
@Public()
@Controller('auth')
export class RefreshController {
  constructor(private readonly refresh: RefreshService) {}

  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({
    description:
      'Trades a refresh token for a new pair of the same family. The token ' +
      'sent stops working; sending it again revokes the whole family.',
  })
  @ZodResponse({ status: 200, type: AuthTokens })
  @ApiProblems('UNAUTHENTICATED', 'TOO_MANY_REQUESTS')
  renew(@Body() body: RefreshRequest): Promise<AuthTokens> {
    return this.refresh.renew(body.refreshToken);
  }
}
