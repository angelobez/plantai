import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiResponse, ApiTags } from '@nestjs/swagger';
import { ApiProblems } from '../../openapi/api-problems.decorator';
import { Public } from '../public.decorator';
import { LogoutRequest } from './logout.dto';
import { LogoutService } from './logout.service';

@ApiTags('Auth')
// Authenticated by the refresh token itself: the access token may have expired.
@Public()
@Controller('auth')
export class LogoutController {
  constructor(private readonly logoutService: LogoutService) {}

  @Post('logout')
  @HttpCode(204)
  @ApiResponse({
    status: 204,
    description:
      'No body. The refresh token is revoked; the same answer when it was ' +
      'already revoked, expired or unknown',
  })
  @ApiProblems('TOO_MANY_REQUESTS')
  async logout(@Body() body: LogoutRequest): Promise<void> {
    await this.logoutService.logout(body.refreshToken);
  }
}
