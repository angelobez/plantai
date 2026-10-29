import { Injectable } from '@nestjs/common';
import { Sessions } from '../sessions';

@Injectable()
export class LogoutService {
  constructor(private readonly sessions: Sessions) {}

  /**
   * Ends the session of [refreshToken], so neither the app nor a copy of it
   * can renew it. Only that session: the User's other ones go on.
   */
  logout(refreshToken: string): Promise<void> {
    return this.sessions.revokeToken(refreshToken);
  }
}
