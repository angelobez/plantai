import { z } from 'zod';

// Fields every auth body validates the same way, so the routes agree.

/** citext in the database: the case does not matter. */
export const emailField = z.email().max(254);

/** At least 8 characters, no composition rule. */
export const passwordField = z.string().min(8).max(128);

export const emailCodeField = z
  .string()
  .regex(/^\d{6}$/, 'must be 6 digits')
  .describe('The 6-digit code from the e-mail');
