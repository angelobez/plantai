import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { emailCodeField, emailField, passwordField } from '../auth-tokens.dto';

export class SignupRequest extends createZodDto(
  z.object({
    name: z
      .string()
      .trim()
      .min(1)
      .max(80)
      .describe('Neighbors see only the first name in the listings'),
    email: emailField,
    password: passwordField,
  }),
) {}

export class VerifyEmailRequest extends createZodDto(
  z.object({ email: emailField, code: emailCodeField }),
) {}
