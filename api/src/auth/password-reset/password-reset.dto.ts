import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { emailCodeField, emailField, passwordField } from '../auth-tokens.dto';

export class PasswordResetRequest extends createZodDto(
  z.object({ email: emailField }),
) {}

export class PasswordResetConfirmRequest extends createZodDto(
  z.object({
    email: emailField,
    code: emailCodeField,
    newPassword: passwordField,
  }),
) {}
