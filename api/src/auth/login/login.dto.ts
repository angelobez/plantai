import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import { emailField } from '../auth-tokens.dto';

export class LoginRequest extends createZodDto(
  z.object({
    email: emailField,
    // No minimum beyond "not empty": a short password is just a wrong one.
    password: z.string().min(1).max(128),
  }),
) {}
