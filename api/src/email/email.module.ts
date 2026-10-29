import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env';
import { EmailSender } from './email-sender';
import { LogEmailSender } from './log-email-sender';
import { ResendEmailSender } from './resend-email-sender';

/** Picks the {@link EmailSender}: Resend with `RESEND_API_KEY`, the log without. */
export function createEmailSender(env: Env): EmailSender {
  return env.RESEND_API_KEY
    ? new ResendEmailSender({
        apiKey: env.RESEND_API_KEY,
        from: env.EMAIL_FROM,
      })
    : new LogEmailSender();
}

@Global()
@Module({
  providers: [
    { provide: EmailSender, inject: [ENV], useFactory: createEmailSender },
  ],
  exports: [EmailSender],
})
export class EmailModule {}
