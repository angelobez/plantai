import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { emailCodeField, emailField, passwordField } from '../auth-fields';

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
